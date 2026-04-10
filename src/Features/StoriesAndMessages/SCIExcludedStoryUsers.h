// Persistent per-user exclusion list for story read-receipts. Lookup is by
// user pk (string). Excluded users get normal seen behavior — your view
// shows up in their viewer list as if RyukGram weren't installed.
#import <Foundation/Foundation.h>

@interface SCIExcludedStoryUsers : NSObject

+ (BOOL)isFeatureEnabled;
+ (BOOL)isBlockSelectedMode;

+ (BOOL)isUserPKExcluded:(NSString *)pk;
+ (BOOL)isInList:(NSString *)pk;
+ (NSDictionary *)entryForPK:(NSString *)pk;
+ (NSArray<NSDictionary *> *)allEntries;
+ (NSUInteger)count;

+ (void)addOrUpdateEntry:(NSDictionary *)entry; // {pk, username, fullName}
+ (void)removePK:(NSString *)pk;

@end
