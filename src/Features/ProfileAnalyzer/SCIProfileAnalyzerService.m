#import "SCIProfileAnalyzerService.h"
#import "../../Networking/SCIInstagramAPI.h"
#import "../../Utils.h"

const NSInteger SCIProfileAnalyzerMaxFollowerCount = 13000;

#define SCI_PA_PAGE_DELAY_S 0.25   // rate-limit cushion between pages

@interface SCIProfileAnalyzerService () {
@public
    NSInteger _expectedFollowers;
    NSInteger _expectedFollowing;
}
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, assign) BOOL isRunning;
@end

@implementation SCIProfileAnalyzerService

+ (instancetype)sharedService {
    static SCIProfileAnalyzerService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}

- (void)cancel { self.cancelled = YES; }

- (void)finishWithSnapshot:(SCIProfileAnalyzerSnapshot *)s error:(NSError *)e completion:(SCIPACompletion)completion {
    self.isRunning = NO;
    self.cancelled = NO;
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(s, e); });
}

- (NSError *)errorWithCode:(SCIProfileAnalyzerError)code message:(NSString *)msg {
    return [NSError errorWithDomain:@"SCIProfileAnalyzer" code:code
                           userInfo:@{ NSLocalizedDescriptionKey: msg ?: @"" }];
}

- (void)runForSelfWithHeaderInfo:(SCIPAHeaderInfo)headerInfo
                        progress:(SCIPAProgress)progress
                      completion:(SCIPACompletion)completion {
    if (self.isRunning) {
        if (completion) completion(nil, [self errorWithCode:SCIProfileAnalyzerErrorCancelled
                                                    message:SCILocalized(@"Another analysis is already running")]);
        return;
    }
    self.isRunning = YES;
    self.cancelled = NO;

    NSString *selfPK = [SCIUtils currentUserPK];
    if (!selfPK.length) {
        [self finishWithSnapshot:nil
                           error:[self errorWithCode:SCIProfileAnalyzerErrorNoSession message:SCILocalized(@"No active Instagram session found")]
                      completion:completion];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self reportProgress:progress status:SCILocalized(@"Fetching profile info…") fraction:0.02];

    [SCIInstagramAPI sendRequestWithMethod:@"GET"
                                      path:[NSString stringWithFormat:@"users/%@/info/", selfPK]
                                      body:nil
                                completion:^(NSDictionary *resp, NSError *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.cancelled) {
            [strongSelf finishWithSnapshot:nil error:[strongSelf errorWithCode:SCIProfileAnalyzerErrorCancelled message:SCILocalized(@"Cancelled")]
                                completion:completion];
            return;
        }
        NSDictionary *user = [resp[@"user"] isKindOfClass:[NSDictionary class]] ? resp[@"user"] : nil;
        if (!user) {
            [strongSelf finishWithSnapshot:nil
                                     error:[strongSelf errorWithCode:SCIProfileAnalyzerErrorNetwork message:SCILocalized(@"Couldn't fetch profile information")]
                                completion:completion];
            return;
        }
        NSInteger followerCount = [user[@"follower_count"] integerValue];
        if (followerCount > SCIProfileAnalyzerMaxFollowerCount) {
            [strongSelf finishWithSnapshot:nil
                                     error:[strongSelf errorWithCode:SCIProfileAnalyzerErrorTooManyFollowers
                                                              message:SCILocalized(@"Too many followers to analyze")]
                                completion:completion];
            return;
        }

        SCIProfileAnalyzerSnapshot *snap = [SCIProfileAnalyzerSnapshot new];
        snap.selfPK = selfPK;
        snap.selfUsername = user[@"username"];
        snap.selfFullName = user[@"full_name"];
        snap.selfProfilePicURL = user[@"profile_pic_url"];
        snap.followerCount = followerCount;
        snap.followingCount = [user[@"following_count"] integerValue];
        snap.mediaCount = [user[@"media_count"] integerValue];
        snap.scanDate = [NSDate date];

        strongSelf->_expectedFollowers = followerCount;
        strongSelf->_expectedFollowing = snap.followingCount;

        if (headerInfo) dispatch_async(dispatch_get_main_queue(), ^{ headerInfo(user); });
        [strongSelf fetchFollowersForPK:selfPK snapshot:snap progress:progress completion:completion];
    }];
}

- (void)reportProgress:(SCIPAProgress)p status:(NSString *)s fraction:(double)f {
    if (!p) return;
    dispatch_async(dispatch_get_main_queue(), ^{ p(s, f); });
}

#pragma mark - Paginated fetchers

- (void)fetchFollowersForPK:(NSString *)pk
                   snapshot:(SCIProfileAnalyzerSnapshot *)snap
                   progress:(SCIPAProgress)progress
                 completion:(SCIPACompletion)completion {
    NSMutableArray *acc = [NSMutableArray array];
    [self pagePath:[NSString stringWithFormat:@"friendships/%@/followers/", pk]
               acc:acc
              maxId:nil
              total:snap.followerCount
             stage:@"followers"
          progress:progress
        completion:^(NSArray *users, NSError *error) {
        if (error || self.cancelled) {
            [self finishWithSnapshot:nil error:error ?: [self errorWithCode:SCIProfileAnalyzerErrorCancelled message:SCILocalized(@"Cancelled")]
                          completion:completion];
            return;
        }
        snap.followers = users;
        [self fetchFollowingForPK:pk snapshot:snap progress:progress completion:completion];
    }];
}

- (void)fetchFollowingForPK:(NSString *)pk
                   snapshot:(SCIProfileAnalyzerSnapshot *)snap
                   progress:(SCIPAProgress)progress
                 completion:(SCIPACompletion)completion {
    NSMutableArray *acc = [NSMutableArray array];
    [self pagePath:[NSString stringWithFormat:@"friendships/%@/following/", pk]
               acc:acc
              maxId:nil
              total:snap.followingCount
             stage:@"following"
          progress:progress
        completion:^(NSArray *users, NSError *error) {
        if (error || self.cancelled) {
            [self finishWithSnapshot:nil error:error ?: [self errorWithCode:SCIProfileAnalyzerErrorCancelled message:SCILocalized(@"Cancelled")]
                          completion:completion];
            return;
        }
        snap.following = users;
        [self finishWithSnapshot:snap error:nil completion:completion];
    }];
}

- (void)pagePath:(NSString *)basePath
             acc:(NSMutableArray *)acc
           maxId:(NSString *)maxId
           total:(NSInteger)total
           stage:(NSString *)stage
        progress:(SCIPAProgress)progress
      completion:(void(^)(NSArray *users, NSError *error))completion {
    if (self.cancelled) {
        completion(nil, [self errorWithCode:SCIProfileAnalyzerErrorCancelled message:SCILocalized(@"Cancelled")]);
        return;
    }
    NSString *path = maxId.length ? [NSString stringWithFormat:@"%@?max_id=%@", basePath, maxId] : basePath;

    __weak typeof(self) weakSelf = self;
    [SCIInstagramAPI sendRequestWithMethod:@"GET" path:path body:nil completion:^(NSDictionary *resp, NSError *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) { completion(nil, [strongSelf errorWithCode:SCIProfileAnalyzerErrorNetwork message:error.localizedDescription]); return; }

        NSArray *users = resp[@"users"];
        if ([users isKindOfClass:[NSArray class]]) {
            for (NSDictionary *d in users) {
                SCIProfileAnalyzerUser *u = [SCIProfileAnalyzerUser userFromAPIDict:d];
                if (u) [acc addObject:u];
            }
        }
        // Weight each stage by its share of expected work; 3% reserved for user-info.
        NSInteger followerTarget = strongSelf->_expectedFollowers;
        NSInteger followingTarget = strongSelf->_expectedFollowing;
        double total0 = MAX(1, followerTarget + followingTarget);
        double stageWeight = ([stage isEqualToString:@"followers"] ? followerTarget : followingTarget) / total0;
        double stageOffset = ([stage isEqualToString:@"followers"] ? 0.0 : (double)followerTarget / total0);
        double stageLocal = total > 0 ? MIN(1.0, (double)acc.count / (double)total) : 0;
        double frac = 0.03 + (stageOffset + stageLocal * stageWeight) * 0.97;
        NSString *fmt = [stage isEqualToString:@"followers"]
            ? SCILocalized(@"Fetching followers (%lu/%ld)…")
            : SCILocalized(@"Fetching following (%lu/%ld)…");
        NSString *label = [NSString stringWithFormat:fmt, (unsigned long)acc.count, (long)total];
        [strongSelf reportProgress:progress status:label fraction:frac];

        id next = resp[@"next_max_id"];
        NSString *nextMax = [next isKindOfClass:[NSString class]] ? next : ([next respondsToSelector:@selector(stringValue)] ? [next stringValue] : nil);
        if (!nextMax.length || strongSelf.cancelled) {
            completion(acc, strongSelf.cancelled ? [strongSelf errorWithCode:SCIProfileAnalyzerErrorCancelled message:SCILocalized(@"Cancelled")] : nil);
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCI_PA_PAGE_DELAY_S * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [strongSelf pagePath:basePath acc:acc maxId:nextMax total:total stage:stage progress:progress completion:completion];
        });
    }];
}

@end
