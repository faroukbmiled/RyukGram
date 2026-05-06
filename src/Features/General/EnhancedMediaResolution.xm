// Increase IG CDN media variant by spoofing iPad Pro 12.9" dimensions/scale
// in the outgoing User-Agent. The CDN picks variants from the UA's `<W>x<H>`
// and `scale=<s>` tokens. Hooks NSMutableURLRequest header setters + IGURLRequest.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"

static NSString *const kSCIEnhancedMediaResolutionDefaultsKey = @"enhanced_media_resolution";

static const NSInteger kSCIHighResUserAgentWidth  = 2064;
static const NSInteger kSCIHighResUserAgentHeight = 2752;
static const CGFloat   kSCIHighResUserAgentScale  = 3.0;

static BOOL SCIEnhancedMediaResolutionEnabled(void) {
    return [SCIUtils getBoolPref:kSCIEnhancedMediaResolutionDefaultsKey];
}

// Replaces `\d{3,4}x\d{3,4}` and `scale=\d+\.\d+` tokens.
static NSString *SCIHighResUserAgentStringFromString(NSString *userAgent) {
    if (userAgent.length == 0) return userAgent;

    NSError *error = nil;
    NSRegularExpression *dimensionRegex =
        [NSRegularExpression regularExpressionWithPattern:@"\\d{3,4}x\\d{3,4}" options:0 error:&error];
    NSString *dimensionTemplate = [NSString stringWithFormat:@"%ldx%ld",
                                    (long)kSCIHighResUserAgentWidth, (long)kSCIHighResUserAgentHeight];
    NSString *step1 = [dimensionRegex stringByReplacingMatchesInString:userAgent
                                                               options:0
                                                                 range:NSMakeRange(0, userAgent.length)
                                                          withTemplate:dimensionTemplate];

    NSRegularExpression *scaleRegex =
        [NSRegularExpression regularExpressionWithPattern:@"scale=\\d+\\.\\d+" options:0 error:&error];
    NSString *scaleTemplate = [NSString stringWithFormat:@"scale=%.2f", kSCIHighResUserAgentScale];
    return [scaleRegex stringByReplacingMatchesInString:step1
                                                options:0
                                                  range:NSMakeRange(0, step1.length)
                                           withTemplate:scaleTemplate];
}

static NSString *SCIHighResHeaderValueIfNeeded(NSString *value, NSString *field) {
    if (!SCIEnhancedMediaResolutionEnabled()) return value;
    if (![value isKindOfClass:[NSString class]] || ![field isKindOfClass:[NSString class]] || field.length == 0) return value;
    if ([field caseInsensitiveCompare:@"User-Agent"] != NSOrderedSame) return value;
    return SCIHighResUserAgentStringFromString(value);
}

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    %orig(SCIHighResHeaderValueIfNeeded(value, field), field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary *)headerFields {
    if (!SCIEnhancedMediaResolutionEnabled() || headerFields.count == 0) {
        %orig(headerFields);
        return;
    }
    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:headerFields];
    for (NSString *key in headerFields) {
        if (![key isKindOfClass:[NSString class]]) continue;
        if ([key caseInsensitiveCompare:@"User-Agent"] != NSOrderedSame) continue;
        id existing = headers[key];
        if ([existing isKindOfClass:[NSString class]]) {
            headers[key] = SCIHighResUserAgentStringFromString((NSString *)existing);
        }
        break;
    }
    %orig(headers);
}

%end

%hook IGURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    %orig(SCIHighResHeaderValueIfNeeded(value, field), field);
}

%end
