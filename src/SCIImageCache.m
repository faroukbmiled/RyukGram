#import "SCIImageCache.h"
#import <CommonCrypto/CommonDigest.h>

static NSCache *memCache(void) {
    static NSCache *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        c = [NSCache new];
        // Tuned for long Profile Analyzer lists — 64 was evicting visible
        // rows mid-scroll so revisits showed grey placeholders.
        c.countLimit = 512;
    });
    return c;
}

static NSString *diskDir(void) {
    static NSString *dir;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *base = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        dir = [base stringByAppendingPathComponent:@"RyukGramImages"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

static NSString *hashKey(NSString *urlString) {
    const char *cstr = urlString.UTF8String;
    unsigned char hash[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cstr, (CC_LONG)strlen(cstr), hash);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}

@implementation SCIImageCache

+ (void)loadImageFromURL:(NSURL *)url completion:(void (^)(UIImage *))completion {
    if (!url || !completion) return;
    NSString *key = url.absoluteString;

    void (^deliver)(UIImage *) = ^(UIImage *image) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
    };

    UIImage *hit = [memCache() objectForKey:key];
    if (hit) { deliver(hit); return; }

    NSString *path = [diskDir() stringByAppendingPathComponent:hashKey(key)];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSData *data = [NSData dataWithContentsOfFile:path];
            UIImage *image = data ? [UIImage imageWithData:data] : nil;
            if (image) [memCache() setObject:image forKey:key];
            deliver(image);
        });
        return;
    }

    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                 completionHandler:^(NSData *data, NSURLResponse *_r, NSError *_e) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        if (image) {
            [memCache() setObject:image forKey:key];
            [data writeToFile:path atomically:YES];
        }
        deliver(image);
    }] resume];
}

+ (void)loadDataFromURL:(NSURL *)url completion:(void (^)(NSData *))completion {
    if (!url || !completion) return;
    void (^deliver)(NSData *) = ^(NSData *data) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(data); });
    };

    NSString *path = [diskDir() stringByAppendingPathComponent:hashKey(url.absoluteString)];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            deliver([NSData dataWithContentsOfFile:path]);
        });
        return;
    }

    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                 completionHandler:^(NSData *data, NSURLResponse *_r, NSError *_e) {
        if (data) [data writeToFile:path atomically:YES];
        deliver(data);
    }] resume];
}

@end
