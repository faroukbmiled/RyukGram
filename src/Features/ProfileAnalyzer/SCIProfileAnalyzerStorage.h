#import <Foundation/Foundation.h>
#import "SCIProfileAnalyzerModels.h"

NS_ASSUME_NONNULL_BEGIN

// Posted on every save/update/reset. userInfo carries @"user_pk".
extern NSNotificationName const SCIProfileAnalyzerDataDidChangeNotification;

// Per-account on-disk store: snapshots + optional baseline + header cache + visit log.
@interface SCIProfileAnalyzerStorage : NSObject

#pragma mark - Snapshots

+ (nullable SCIProfileAnalyzerSnapshot *)currentSnapshotForUserPK:(NSString *)userPK;
+ (nullable SCIProfileAnalyzerSnapshot *)previousSnapshotForUserPK:(NSString *)userPK;
+ (nullable SCIProfileAnalyzerSnapshot *)baselineSnapshotForUserPK:(NSString *)userPK;
+ (BOOL)saveBaselineSnapshot:(SCIProfileAnalyzerSnapshot *)snapshot forUserPK:(NSString *)userPK;
+ (void)clearBaselineForUserPK:(NSString *)userPK;

// Rotates current → previous, then writes the new current.
+ (BOOL)saveSnapshot:(SCIProfileAnalyzerSnapshot *)snapshot forUserPK:(NSString *)userPK;
// Overwrites current without rotating — used for in-app follow/unfollow mutations.
+ (BOOL)updateCurrentSnapshot:(SCIProfileAnalyzerSnapshot *)snapshot forUserPK:(NSString *)userPK;

+ (void)resetForUserPK:(NSString *)userPK;
+ (void)resetAll;

#pragma mark - Header cache

+ (nullable NSDictionary *)headerInfoForUserPK:(NSString *)userPK;
+ (void)saveHeaderInfo:(NSDictionary *)info forUserPK:(NSString *)userPK;

#pragma mark - Backup / restore

+ (NSDictionary *)exportedDict;
+ (BOOL)importFromDict:(NSDictionary *)dict;

#pragma mark - Visited profiles

+ (NSArray<SCIProfileAnalyzerVisit *> *)visitedProfilesForUserPK:(NSString *)userPK;
+ (void)recordVisitForUser:(SCIProfileAnalyzerUser *)user forUserPK:(NSString *)userPK;
+ (void)removeVisitForUserPK:(NSString *)userPK visitedPK:(NSString *)visitedPK;
+ (void)clearVisitsForUserPK:(NSString *)userPK;
// Refresh metadata for an existing visit without bumping last_seen / visit_count.
+ (void)refreshVisitedUser:(SCIProfileAnalyzerUser *)user forUserPK:(NSString *)userPK;

@end

NS_ASSUME_NONNULL_END
