#import "SCIDirectUserResolver.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Weak so account-switch / logout drops it; the hook re-stamps on every
// cache delta.
static __weak id sciCachedApplicator = nil;

void sciDirectUserResolverSetActiveApplicator(id applicator) {
    if (!applicator) return;
    sciCachedApplicator = applicator;
}

#pragma mark - IGUser field extraction

NSString *sciDirectUserResolverPKFromUser(id user) {
    if (!user) return nil;
    @try {
        for (NSString *key in @[@"pk", @"instagramUserID", @"instagramUserId", @"userID", @"userId", @"identifier"]) {
            @try {
                id v = [user valueForKey:key];
                if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) return v;
                if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
            } @catch (__unused id e) {}
        }
    } @catch (__unused id e) {}
    return nil;
}

NSString *sciDirectUserResolverUsernameFromUser(id user) {
    if (!user) return nil;
    @try {
        id un = [user valueForKey:@"username"];
        if ([un isKindOfClass:[NSString class]] && [(NSString *)un length] > 0) return un;
    } @catch (__unused id e) {}
    return nil;
}

NSString *sciDirectUserResolverProfilePicURLStringFromUser(id user) {
    if (!user) return nil;
    @try {
        for (NSString *key in @[@"profilePicURL", @"profilePictureURL", @"profileImageURL"]) {
            @try {
                id v = [user valueForKey:key];
                if ([v isKindOfClass:[NSURL class]]) return [(NSURL *)v absoluteString];
                if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) return v;
            } @catch (__unused id e) {}
        }
    } @catch (__unused id e) {}
    return nil;
}

#pragma mark - PK lookup

// applicator._userMap._objectMap._objects (NSMapTable). IG mutates the map
// on its own queue so the lookup hops onto _queue when present.
id sciDirectUserResolverUserForPK(NSString *pk) {
    if (pk.length == 0) return nil;
    id applicator = sciCachedApplicator;
    if (!applicator) return nil;

    @try {
        Ivar umIv = class_getInstanceVariable([applicator class], "_userMap");
        id userMap = umIv ? object_getIvar(applicator, umIv) : nil;
        if (!userMap) return nil;
        Ivar omIv = class_getInstanceVariable([userMap class], "_objectMap");
        id objMap = omIv ? object_getIvar(userMap, omIv) : nil;
        if (!objMap) return nil;
        Ivar oIv = class_getInstanceVariable([objMap class], "_objects");
        id store = oIv ? object_getIvar(objMap, oIv) : nil;
        if (!store) return nil;

        Ivar qIv = class_getInstanceVariable([userMap class], "_queue");
        id qObj = qIv ? object_getIvar(userMap, qIv) : nil;
        Class dqCls = NSClassFromString(@"OS_dispatch_queue");
        dispatch_queue_t userQueue = (dqCls && [qObj isKindOfClass:dqCls]) ? (dispatch_queue_t)qObj : nil;

        __block id result = nil;
        dispatch_block_t lookup = ^{
            id user = nil;
            if ([store isKindOfClass:[NSMapTable class]]) {
                NSMapTable *mt = (NSMapTable *)store;
                user = [mt objectForKey:pk];
                if (!user) user = [mt objectForKey:@([pk longLongValue])];
                if (!user) {
                    for (id candidate in [mt objectEnumerator]) {
                        NSString *cpk = sciDirectUserResolverPKFromUser(candidate);
                        if (cpk && [cpk isEqualToString:pk]) { user = candidate; break; }
                    }
                }
            } else if ([store isKindOfClass:[NSDictionary class]]) {
                user = ((NSDictionary *)store)[pk];
                if (!user) user = ((NSDictionary *)store)[@([pk longLongValue])];
            }
            result = user;
        };

        if (userQueue) {
            @try { dispatch_sync(userQueue, lookup); }
            @catch (__unused id e) { lookup(); }
        } else {
            lookup();
        }
        return result;
    } @catch (__unused id e) {}
    return nil;
}

NSString *sciDirectUserResolverUsernameForPK(NSString *pk) {
    return sciDirectUserResolverUsernameFromUser(sciDirectUserResolverUserForPK(pk));
}

NSString *sciDirectUserResolverProfilePicURLStringForPK(NSString *pk) {
    return sciDirectUserResolverProfilePicURLStringFromUser(sciDirectUserResolverUserForPK(pk));
}
