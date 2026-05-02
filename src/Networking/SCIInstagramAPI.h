// Reusable wrapper for Instagram private API calls. Reads the Bearer token
// for the active account from IG's keychain group and uses it to talk to
// the legacy /api/v1/ endpoints. Account switches are picked up automatically.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^SCIAPICompletion)(NSDictionary * _Nullable response, NSError * _Nullable error);
typedef void(^SCIAPIStatusesCompletion)(NSDictionary * _Nullable statuses, NSError * _Nullable error);

@interface SCIInstagramAPI : NSObject

// ============ Generic ============

// `path` is the part after /api/v1/, e.g. "friendships/create/123/".
// `body` is form-encoded if non-nil. `completion` runs on the main queue.
+ (void)sendRequestWithMethod:(NSString *)method
                         path:(NSString *)path
                         body:(nullable NSDictionary *)body
                   completion:(nullable SCIAPICompletion)completion;

// ============ Friendships ============

+ (void)followUserPK:(NSString *)pk completion:(nullable SCIAPICompletion)completion;
+ (void)unfollowUserPK:(NSString *)pk completion:(nullable SCIAPICompletion)completion;

// Bulk-fetch friendship statuses for a set of user PKs in one round trip.
// Statuses dict maps pk → {following, outgoing_request, is_private, ...}.
+ (void)fetchFriendshipStatusesForPKs:(NSArray<NSString *> *)pks
                           completion:(nullable SCIAPIStatusesCompletion)completion;

// ============ Media ============

// Fetch a single media item. Response carries `items[0]` with `user`, `usertags.in[].user`, etc.
+ (void)fetchMediaInfoForMediaId:(NSString *)mediaId completion:(nullable SCIAPICompletion)completion;

@end

NS_ASSUME_NONNULL_END
