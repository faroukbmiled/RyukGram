#import "SCICacheManager.h"
#import <stdatomic.h>
#import <fts.h>
#import <sys/stat.h>
#import <dirent.h>
#import <removefile.h>

static NSString *const kAutoClearModeKey = @"cache_auto_clear_mode";
static NSString *const kLastAutoClearKey = @"cache_last_auto_clear_ts";
static NSString *const kLastKnownSizeKey = @"cache_last_known_size";

NSString *const SCICacheSizeDidUpdateNotification = @"SCICacheSizeDidUpdateNotification";

static _Atomic uint64_t gCachedSize = 0;
static dispatch_once_t gLoadPersistedOnce;

static void sciLoadPersistedSizeOnce(void) {
    dispatch_once(&gLoadPersistedOnce, ^{
        uint64_t stored = (uint64_t)[[NSUserDefaults standardUserDefaults] doubleForKey:kLastKnownSizeKey];
        atomic_store(&gCachedSize, stored);
    });
}

static NSArray<NSString *> *sciCacheDirs(void) {
    NSMutableArray *dirs = [NSMutableArray array];
    NSArray *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (caches.firstObject) [dirs addObject:caches.firstObject];
    NSArray *appSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if (appSupport.firstObject) [dirs addObject:appSupport.firstObject];
    NSString *tmp = NSTemporaryDirectory();
    if (tmp.length) [dirs addObject:tmp];
    return dirs;
}

// Top-level "RyukGram" folder under any cache root is RyukGram user data.
// Gallery (Documents/Gallery) is outside `sciCacheDirs()` so already safe.
// Derived caches (RyukGramImages, RyukGramChangelog) are intentionally wiped.
static BOOL sciIsProtectedEntryName(const char *name) {
    return strcmp(name, "RyukGram") == 0;
}

// POSIX fts — avoids the NSDirectoryEnumerator per-entry alloc overhead.
static uint64_t sciDirectorySize(NSString *path) {
    const char *root = [path fileSystemRepresentation];
    if (!root) return 0;
    char * const paths[] = { (char *)root, NULL };
    FTS *fts = fts_open(paths, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, NULL);
    if (!fts) return 0;
    uint64_t total = 0;
    FTSENT *ent;
    while ((ent = fts_read(fts))) {
        // Don't descend into RyukGram user-data subtrees.
        if (ent->fts_info == FTS_D && ent->fts_level == 1 &&
            sciIsProtectedEntryName(ent->fts_name)) {
            fts_set(fts, ent, FTS_SKIP);
            continue;
        }
        if (ent->fts_info == FTS_F && ent->fts_statp) {
            total += (uint64_t)ent->fts_statp->st_size;
        }
    }
    fts_close(fts);
    return total;
}

// Directory basenames that hold DM history, drafts, and Notes. Skipped
// at any depth when "Preserve messages database" is on.
static BOOL sciIsProtectedMessagesEntryName(const char *name) {
    static const char * const kProtected[] = {
        "DirectSQLiteDatabase",
        "IGDirectE2EEDiskStore",
        "direct",
        "Notes",
        "unified-drafts",
        "saved-drafts",
        "Drafts",
        "PostCreation",
        "ThreadCreation",
        NULL,
    };
    for (const char * const *p = kProtected; *p; p++) {
        if (strcmp(name, *p) == 0) return YES;
    }
    if (strncmp(name, "Drafts_", 7) == 0) return YES;
    return NO;
}

// Recursive delete of directory contents — the top-level dir itself is
// preserved so IG's file handles stay valid, and RyukGram subtrees are
// always skipped. When preserveMessagesDB is YES, walks per-file via fts
// to also skip message stores at any depth.
static void sciDeleteDirectoryContents(NSString *path, BOOL preserveMessagesDB) {
    const char *root = [path fileSystemRepresentation];
    if (!root) return;

    if (!preserveMessagesDB) {
        DIR *dp = opendir(root);
        if (!dp) return;
        struct dirent *de;
        while ((de = readdir(dp))) {
            if (de->d_name[0] == '.' && (de->d_name[1] == 0 ||
                (de->d_name[1] == '.' && de->d_name[2] == 0))) continue;
            if (sciIsProtectedEntryName(de->d_name)) continue;
            char full[PATH_MAX];
            snprintf(full, sizeof(full), "%s/%s", root, de->d_name);
            removefile(full, NULL, REMOVEFILE_RECURSIVE);
        }
        closedir(dp);
        return;
    }

    char * const paths[] = { (char *)root, NULL };
    FTS *fts = fts_open(paths, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, NULL);
    if (!fts) return;
    FTSENT *ent;
    while ((ent = fts_read(fts))) {
        if (ent->fts_level == 0) continue;
        if (ent->fts_info == FTS_D) {
            if (ent->fts_level == 1 && sciIsProtectedEntryName(ent->fts_name)) {
                fts_set(fts, ent, FTS_SKIP);
                continue;
            }
            if (sciIsProtectedMessagesEntryName(ent->fts_name)) {
                fts_set(fts, ent, FTS_SKIP);
                continue;
            }
            continue;
        }
        if (ent->fts_info == FTS_F || ent->fts_info == FTS_SL ||
            ent->fts_info == FTS_SLNONE || ent->fts_info == FTS_DEFAULT) {
            unlink(ent->fts_accpath);
        } else if (ent->fts_info == FTS_DP) {
            rmdir(ent->fts_accpath);
        }
    }
    fts_close(fts);
}

@implementation SCICacheManager

// Transient mode reports the size to the caller but skips persisting it
// and firing the update notification — used by the "Show cache size" off
// tap path to scan on demand without leaking state.
+ (void)_scanWithQos:(qos_class_t)qos
           transient:(BOOL)transient
          completion:(void(^)(uint64_t))completion {
    dispatch_queue_t q = dispatch_get_global_queue(qos, 0);
    dispatch_async(q, ^{
        NSArray<NSString *> *dirs = sciCacheDirs();
        __block _Atomic uint64_t running = 0;
        dispatch_group_t group = dispatch_group_create();
        for (NSString *d in dirs) {
            dispatch_group_async(group, q, ^{
                atomic_fetch_add(&running, sciDirectorySize(d));
            });
        }
        dispatch_group_async(group, q, ^{
            atomic_fetch_add(&running, (uint64_t)[[NSURLCache sharedURLCache] currentDiskUsage]);
        });
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

        uint64_t total = atomic_load(&running);
        if (!transient) {
            atomic_store(&gCachedSize, total);
            [[NSUserDefaults standardUserDefaults] setDouble:(double)total forKey:kLastKnownSizeKey];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!transient) {
                [[NSNotificationCenter defaultCenter] postNotificationName:SCICacheSizeDidUpdateNotification
                                                                    object:@(total)];
            }
            if (completion) completion(total);
        });
    });
}

+ (void)getCacheSizeWithCompletion:(void(^)(uint64_t))completion {
    [self _scanWithQos:QOS_CLASS_USER_INITIATED transient:NO completion:completion];
}

+ (void)getCacheSizeTransientWithCompletion:(void(^)(uint64_t))completion {
    [self _scanWithQos:QOS_CLASS_USER_INITIATED transient:YES completion:completion];
}

+ (uint64_t)cachedSize {
    sciLoadPersistedSizeOnce();
    return atomic_load(&gCachedSize);
}

+ (void)refreshSizeInBackground {
    [self _scanWithQos:QOS_CLASS_BACKGROUND transient:NO completion:nil];
}

+ (void)refreshSizeInBackgroundIfEnabled {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"cache_auto_check_size"]) return;
    [self refreshSizeInBackground];
}

+ (void)clearCacheWithCompletion:(void(^)(uint64_t))completion {
    dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
    dispatch_async(q, ^{
        // Snapshot the known size; only re-scan if we never measured.
        uint64_t reclaimed = atomic_load(&gCachedSize);
        if (reclaimed == 0) {
            for (NSString *d in sciCacheDirs()) reclaimed += sciDirectorySize(d);
            reclaimed += (uint64_t)[[NSURLCache sharedURLCache] currentDiskUsage];
        }

        BOOL preserveDB = [[NSUserDefaults standardUserDefaults] boolForKey:@"cache_preserve_messages_db"];
        NSArray<NSString *> *dirs = sciCacheDirs();
        dispatch_group_t group = dispatch_group_create();
        for (NSString *d in dirs) {
            dispatch_group_async(group, q, ^{ sciDeleteDirectoryContents(d, preserveDB); });
        }
        dispatch_group_async(group, q, ^{
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
        });
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

        atomic_store(&gCachedSize, 0);
        [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:kLastKnownSizeKey];
        [[NSUserDefaults standardUserDefaults] setDouble:[NSDate date].timeIntervalSince1970
                                                  forKey:kLastAutoClearKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SCICacheSizeDidUpdateNotification
                                                                object:@(0)];
            if (completion) completion(reclaimed);
        });
    });
}

+ (void)runAutoClearIfDue {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:kAutoClearModeKey];
    if (!mode.length || [mode isEqualToString:@"off"]) { [self refreshSizeInBackgroundIfEnabled]; return; }

    NSTimeInterval interval = 0;
    if      ([mode isEqualToString:@"daily"])   interval = 24 * 60 * 60;
    else if ([mode isEqualToString:@"weekly"])  interval = 7 * 24 * 60 * 60;
    else if ([mode isEqualToString:@"monthly"]) interval = 30 * 24 * 60 * 60;
    else { [self refreshSizeInBackgroundIfEnabled]; return; }

    NSTimeInterval last = [[NSUserDefaults standardUserDefaults] doubleForKey:kLastAutoClearKey];
    NSTimeInterval now  = [NSDate date].timeIntervalSince1970;
    if (last > 0 && (now - last) < interval) { [self refreshSizeInBackgroundIfEnabled]; return; }

    [self clearCacheWithCompletion:^(uint64_t bytes) {
        NSLog(@"[RyukGram] auto-clear cache mode=%@ reclaimed=%@", mode, [self formattedSize:bytes]);
    }];
}

+ (NSString *)formattedSize:(uint64_t)bytes {
    return [NSByteCountFormatter stringFromByteCount:(long long)bytes
                                           countStyle:NSByteCountFormatterCountStyleFile];
}

@end
