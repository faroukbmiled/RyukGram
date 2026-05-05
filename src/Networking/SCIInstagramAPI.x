// Reusable IG private API helper. See SCIInstagramAPI.h.

#import "SCIInstagramAPI.h"
#import "../Utils.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/sysctl.h>

#define SCI_API_BASE @"https://i.instagram.com/api/v1/"
#define SCI_APP_ID   @"124024574287414" // public IG iOS app id constant

// User-Agent in IG's exact format, generated from the device + IG bundle.
static NSString *sciUserAgent(void) {
    static NSString *ua = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"424.0.0";
        char machine[64] = {0};
        size_t size = sizeof(machine);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        NSString *device = machine[0] ? [NSString stringWithUTF8String:machine] : @"iPhone15,2";
        NSString *iosVersion = [[UIDevice currentDevice].systemVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        NSString *locale = [NSLocale currentLocale].localeIdentifier ?: @"en_US";
        NSString *lang = [[NSLocale preferredLanguages] firstObject] ?: @"en";
        UIScreen *screen = [UIScreen mainScreen];
        ua = [NSString stringWithFormat:@"Instagram %@ (%@; iOS %@; %@; %@; scale=%.2f; %.0fx%.0f; 0)",
              version, device, iosVersion, locale, lang,
              screen.scale, screen.nativeBounds.size.width, screen.nativeBounds.size.height];
    });
    return ua;
}

// ============ IG runtime accessors ============

static id sciCurrentUserSession(void) { return [SCIUtils activeUserSession]; }
static NSString *sciCurrentUserPK(void) { return [SCIUtils currentUserPK]; }

// Bearer token for the active account, read fresh from
// -[IGUserSession authHeaderManager] -> -[IGUserAuthHeaderManager authHeader].
static NSString *sciAuthHeader(void) {
    @try {
        id session = sciCurrentUserSession();
        if (!session || ![session respondsToSelector:@selector(authHeaderManager)]) return nil;
        id manager = ((id(*)(id, SEL))objc_msgSend)(session, @selector(authHeaderManager));
        if (!manager || ![manager respondsToSelector:@selector(authHeader)]) return nil;
        id header = ((id(*)(id, SEL))objc_msgSend)(manager, @selector(authHeader));
        if ([header isKindOfClass:[NSString class]] && [(NSString *)header length]) return header;
    } @catch (__unused id e) {}
    return nil;
}

// ============ Request building ============

static NSString *sciFormEncode(NSDictionary *params) {
    if (!params.count) return @"";
    NSMutableArray *parts = [NSMutableArray array];
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    for (NSString *key in params) {
        NSString *val = [NSString stringWithFormat:@"%@", params[key]];
        NSString *ek = [key stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        NSString *ev = [val stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        [parts addObject:[NSString stringWithFormat:@"%@=%@", ek, ev]];
    }
    return [parts componentsJoinedByString:@"&"];
}

static NSMutableURLRequest *sciBuildRequest(NSString *method, NSURL *url, NSDictionary *body) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = method ?: @"GET";

    [req setValue:sciUserAgent() forHTTPHeaderField:@"User-Agent"];
    [req setValue:SCI_APP_ID      forHTTPHeaderField:@"X-IG-App-ID"];
    [req setValue:@"WIFI"         forHTTPHeaderField:@"X-IG-Connection-Type"];
    [req setValue:@"en-US"        forHTTPHeaderField:@"Accept-Language"];
    NSString *auth = sciAuthHeader();
    if (auth) [req setValue:auth forHTTPHeaderField:@"Authorization"];

    for (NSHTTPCookie *c in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url]) {
        if ([c.name isEqualToString:@"csrftoken"]) {
            [req setValue:c.value forHTTPHeaderField:@"X-CSRFToken"];
            break;
        }
    }

    if (body) {
        req.HTTPBody = [sciFormEncode(body) dataUsingEncoding:NSUTF8StringEncoding];
        [req setValue:@"application/x-www-form-urlencoded; charset=UTF-8"
            forHTTPHeaderField:@"Content-Type"];
    }
    return req;
}

static void sciPerformRequest(NSMutableURLRequest *req, SCIAPICompletion completion) {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSDictionary *resp = nil;
            if (data.length) {
                @try {
                    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([parsed isKindOfClass:[NSDictionary class]]) resp = parsed;
                } @catch (__unused id e) {}
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(resp, error); });
            }
        }];
    [task resume];
}

@implementation SCIInstagramAPI

// ============ Generic ============

+ (void)sendRequestWithMethod:(NSString *)method
                         path:(NSString *)path
                         body:(NSDictionary *)body
                   completion:(SCIAPICompletion)completion {
    NSString *clean = [path hasPrefix:@"/"] ? [path substringFromIndex:1] : path;
    NSURL *url = [NSURL URLWithString:[SCI_API_BASE stringByAppendingString:clean]];
    sciPerformRequest(sciBuildRequest(method, url, body), completion);
}

// ============ Friendships ============

+ (void)followUserPK:(NSString *)pk completion:(SCIAPICompletion)completion {
    if (!pk.length) { if (completion) completion(nil, nil); return; }
    [self sendRequestWithMethod:@"POST"
                           path:[NSString stringWithFormat:@"friendships/create/%@/", pk]
                           body:@{@"user_id": pk, @"radio_type": @"wifi-none"}
                     completion:completion];
}

+ (void)unfollowUserPK:(NSString *)pk completion:(SCIAPICompletion)completion {
    if (!pk.length) { if (completion) completion(nil, nil); return; }
    [self sendRequestWithMethod:@"POST"
                           path:[NSString stringWithFormat:@"friendships/destroy/%@/", pk]
                           body:@{@"user_id": pk, @"radio_type": @"wifi-none"}
                     completion:completion];
}

+ (void)fetchFriendshipStatusesForPKs:(NSArray<NSString *> *)pks
                           completion:(SCIAPIStatusesCompletion)completion {
    if (!pks.count) { if (completion) completion(nil, nil); return; }
    [self sendRequestWithMethod:@"POST"
                           path:@"friendships/show_many/"
                           body:@{@"user_ids": [pks componentsJoinedByString:@","]}
                     completion:^(NSDictionary *response, NSError *error) {
        NSDictionary *statuses = nil;
        id s = response[@"friendship_statuses"];
        if ([s isKindOfClass:[NSDictionary class]]) statuses = s;
        if (completion) completion(statuses, error);
    }];
}

// ============ Media ============

+ (void)fetchMediaInfoForMediaId:(NSString *)mediaId completion:(SCIAPICompletion)completion {
    if (!mediaId.length) { if (completion) completion(nil, nil); return; }
    [self sendRequestWithMethod:@"GET"
                           path:[NSString stringWithFormat:@"media/%@/info/", mediaId]
                           body:nil
                     completion:completion];
}

@end

