// Shared PK → IGUser resolver. The active IGDirectCacheUpdatesApplicator is
// captured by KeepDeletedMessages's `_applyThreadUpdates:` hook (always
// installed regardless of the keep-deleted pref), so lookups work for any
// feature that lands a senderId.

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void sciDirectUserResolverSetActiveApplicator(id applicator);

id _Nullable sciDirectUserResolverUserForPK(NSString * _Nullable pk);
NSString * _Nullable sciDirectUserResolverUsernameForPK(NSString * _Nullable pk);
NSString * _Nullable sciDirectUserResolverProfilePicURLStringForPK(NSString * _Nullable pk);

// IGUser field extraction — KVC-based, exception-safe.
NSString * _Nullable sciDirectUserResolverPKFromUser(id _Nullable user);
NSString * _Nullable sciDirectUserResolverUsernameFromUser(id _Nullable user);
NSString * _Nullable sciDirectUserResolverProfilePicURLStringFromUser(id _Nullable user);

#ifdef __cplusplus
}
#endif
