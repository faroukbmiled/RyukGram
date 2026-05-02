#import <Foundation/Foundation.h>
#import "SCIProfileAnalyzerModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIProfileAnalyzerError) {
    SCIProfileAnalyzerErrorNoSession = 1,
    SCIProfileAnalyzerErrorTooManyFollowers,
    SCIProfileAnalyzerErrorNetwork,
    SCIProfileAnalyzerErrorCancelled,
};

// Hard cap — refuse to run beyond this follower count to dodge IG rate limits.
extern const NSInteger SCIProfileAnalyzerMaxFollowerCount;

typedef void(^SCIPAProgress)(NSString *status, double fraction);
typedef void(^SCIPACompletion)(SCIProfileAnalyzerSnapshot * _Nullable snapshot, NSError * _Nullable error);
// Fires once after the self-user-info call so the header can paint immediately.
typedef void(^SCIPAHeaderInfo)(NSDictionary *userInfo);

@interface SCIProfileAnalyzerService : NSObject

@property (nonatomic, readonly) BOOL isRunning;

+ (instancetype)sharedService;

- (void)runForSelfWithHeaderInfo:(nullable SCIPAHeaderInfo)headerInfo
                        progress:(SCIPAProgress)progress
                      completion:(SCIPACompletion)completion;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
