#import "SCIExcludedThreads.h"
#import "../../Utils.h"

#define SCI_EXCL_KEY @"excluded_threads"
#define SCI_INCL_KEY @"included_threads"

@implementation SCIExcludedThreads

static NSString *sciActiveTid = nil;

+ (BOOL)isFeatureEnabled {
    return [SCIUtils getBoolPref:@"enable_chat_exclusions"];
}

+ (BOOL)isBlockSelectedMode {
    return [[SCIUtils getStringPref:@"chat_blocking_mode"] isEqualToString:@"block_selected"];
}

+ (NSString *)activeKey {
    return [self isBlockSelectedMode] ? SCI_INCL_KEY : SCI_EXCL_KEY;
}

+ (NSArray<NSDictionary *> *)allEntries {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:[self activeKey]] ?: @[];
}

+ (NSUInteger)count { return [self allEntries].count; }

+ (void)saveAll:(NSArray *)entries {
    [[NSUserDefaults standardUserDefaults] setObject:entries forKey:[self activeKey]];
}

+ (NSDictionary *)entryForThreadId:(NSString *)threadId {
    if (threadId.length == 0) return nil;
    for (NSDictionary *e in [self allEntries]) {
        if ([e[@"threadId"] isEqualToString:threadId]) return e;
    }
    return nil;
}

+ (BOOL)isInList:(NSString *)threadId {
    return [self entryForThreadId:threadId] != nil;
}

+ (BOOL)isThreadIdExcluded:(NSString *)threadId {
    if (![self isFeatureEnabled]) return NO;
    BOOL inList = [self isInList:threadId];
    return [self isBlockSelectedMode] ? !inList : inList;
}

+ (BOOL)shouldKeepDeletedBeBlockedForThreadId:(NSString *)threadId {
    if (![self isFeatureEnabled]) return NO;
    NSDictionary *e = [self entryForThreadId:threadId];

    if ([self isBlockSelectedMode]) {
        // block_selected: listed chats are blocked
        // NOT in list → normal chat → block keep-deleted if default pref is on
        // IN list → blocked chat → keep-deleted should work (not blocked) unless overridden
        if (!e) return [SCIUtils getBoolPref:@"exclusions_default_keep_deleted"];
        SCIKeepDeletedOverride mode = [e[@"keepDeletedOverride"] integerValue];
        if (mode == SCIKeepDeletedOverrideExcluded) return YES;
        if (mode == SCIKeepDeletedOverrideIncluded) return NO;
        return NO; // default: keep-deleted works in blocked chats
    }

    // block_all: listed chats are excluded (behave normally)
    if (!e) return NO;
    SCIKeepDeletedOverride mode = [e[@"keepDeletedOverride"] integerValue];
    if (mode == SCIKeepDeletedOverrideExcluded) return YES;
    if (mode == SCIKeepDeletedOverrideIncluded) return NO;
    return [SCIUtils getBoolPref:@"exclusions_default_keep_deleted"];
}

+ (void)addOrUpdateEntry:(NSDictionary *)entry {
    NSString *tid = entry[@"threadId"];
    if (tid.length == 0) return;
    NSMutableArray *all = [[self allEntries] mutableCopy];
    NSInteger existingIdx = -1;
    for (NSInteger i = 0; i < (NSInteger)all.count; i++) {
        if ([all[i][@"threadId"] isEqualToString:tid]) { existingIdx = i; break; }
    }
    NSMutableDictionary *merged = [entry mutableCopy];
    if (existingIdx >= 0) {
        NSDictionary *old = all[existingIdx];
        if (old[@"addedAt"]) merged[@"addedAt"] = old[@"addedAt"];
        if (old[@"keepDeletedOverride"]) merged[@"keepDeletedOverride"] = old[@"keepDeletedOverride"];
        all[existingIdx] = merged;
    } else {
        if (!merged[@"addedAt"]) merged[@"addedAt"] = @([[NSDate date] timeIntervalSince1970]);
        if (!merged[@"keepDeletedOverride"]) merged[@"keepDeletedOverride"] = @(SCIKeepDeletedOverrideDefault);
        [all addObject:merged];
    }
    [self saveAll:all];
}

+ (void)removeThreadId:(NSString *)threadId {
    if (threadId.length == 0) return;
    NSMutableArray *all = [[self allEntries] mutableCopy];
    [all filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, id _) {
        return ![e[@"threadId"] isEqualToString:threadId];
    }]];
    [self saveAll:all];
}

+ (void)setKeepDeletedOverride:(SCIKeepDeletedOverride)mode forThreadId:(NSString *)threadId {
    if (threadId.length == 0) return;
    NSMutableArray *all = [[self allEntries] mutableCopy];
    for (NSInteger i = 0; i < (NSInteger)all.count; i++) {
        if ([all[i][@"threadId"] isEqualToString:threadId]) {
            NSMutableDictionary *m = [all[i] mutableCopy];
            m[@"keepDeletedOverride"] = @(mode);
            all[i] = m;
            break;
        }
    }
    [self saveAll:all];
}

+ (void)setActiveThreadId:(NSString *)threadId { sciActiveTid = [threadId copy]; }
+ (NSString *)activeThreadId { return sciActiveTid; }
+ (BOOL)isActiveThreadExcluded { return [self isThreadIdExcluded:sciActiveTid]; }

@end
