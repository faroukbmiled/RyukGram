#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Cached user record (one per follower / following / visit entry).
@interface SCIProfileAnalyzerUser : NSObject <NSCopying>

@property (nonatomic, copy) NSString *pk;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy, nullable) NSString *fullName;
@property (nonatomic, copy, nullable) NSString *profilePicURL;
// Stable IG-internal pic id; only changes when the user uploads a new photo.
@property (nonatomic, copy, nullable) NSString *profilePicID;
@property (nonatomic, assign) BOOL isPrivate;
@property (nonatomic, assign) BOOL isVerified;

+ (nullable instancetype)userFromAPIDict:(NSDictionary *)dict;
+ (nullable instancetype)userFromJSONDict:(NSDictionary *)dict;
+ (nullable instancetype)userFromIGUserObject:(id)igUser;
- (NSDictionary *)toJSONDict;

@end

// One visited-profile entry — first/last seen + cumulative count.
@interface SCIProfileAnalyzerVisit : NSObject

@property (nonatomic, strong) SCIProfileAnalyzerUser *user;
@property (nonatomic, strong) NSDate *firstSeen;
@property (nonatomic, strong) NSDate *lastSeen;
@property (nonatomic, assign) NSInteger visitCount;

+ (nullable instancetype)visitFromJSONDict:(NSDictionary *)dict;
- (NSDictionary *)toJSONDict;

@end

// Point-in-time capture of an account's graph + self info; persisted as JSON.
@interface SCIProfileAnalyzerSnapshot : NSObject

@property (nonatomic, strong) NSDate *scanDate;
@property (nonatomic, copy) NSString *selfPK;
@property (nonatomic, copy, nullable) NSString *selfUsername;
@property (nonatomic, copy, nullable) NSString *selfFullName;
@property (nonatomic, copy, nullable) NSString *selfProfilePicURL;
@property (nonatomic, assign) NSInteger followerCount;
@property (nonatomic, assign) NSInteger followingCount;
@property (nonatomic, assign) NSInteger mediaCount;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *followers;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *following;

+ (nullable instancetype)snapshotFromJSONDict:(NSDictionary *)dict;
- (NSDictionary *)toJSONDict;

@end

// Per-user change between snapshots (username / fullName / pic).
@interface SCIProfileAnalyzerProfileChange : NSObject
@property (nonatomic, strong) SCIProfileAnalyzerUser *previous;
@property (nonatomic, strong) SCIProfileAnalyzerUser *current;
@property (nonatomic, readonly) BOOL usernameChanged;
@property (nonatomic, readonly) BOOL fullNameChanged;
@property (nonatomic, readonly) BOOL profilePicChanged;
@end

// Derived category arrays from (current, previous) snapshots.
@interface SCIProfileAnalyzerReport : NSObject

@property (nonatomic, strong, nullable) SCIProfileAnalyzerSnapshot *current;
@property (nonatomic, strong, nullable) SCIProfileAnalyzerSnapshot *previous;

@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *mutualFollowers;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *notFollowingYouBack;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *youDontFollowBack;
// "recent" / "lost" — `new*` is reserved by ARC's Cocoa new-family rule.
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *recentFollowers;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *lostFollowers;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *youStartedFollowing;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerUser *> *youUnfollowed;
@property (nonatomic, copy) NSArray<SCIProfileAnalyzerProfileChange *> *profileUpdates;

+ (SCIProfileAnalyzerReport *)reportFromCurrent:(nullable SCIProfileAnalyzerSnapshot *)current
                                        previous:(nullable SCIProfileAnalyzerSnapshot *)previous;

@end

NS_ASSUME_NONNULL_END
