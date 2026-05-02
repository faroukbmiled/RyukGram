#import "SCIDashParser.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation SCIDashRepresentation
@end

// Resolve _fieldCache per class (walking the hierarchy). Caching the ivar
// against IGAPIStorableObject and then reading that offset from an unrelated
// class like IGVideo segfaults — ivar offsets aren't shared.
static id sciDashFieldCache(id obj, NSString *key) {
    if (!obj || !key.length) return nil;
    Ivar fcIvar = NULL;
    @try {
        for (Class c = [obj class]; c && !fcIvar; c = class_getSuperclass(c)) {
            fcIvar = class_getInstanceVariable(c, "_fieldCache");
        }
    } @catch (__unused id e) { return nil; }
    if (!fcIvar) return nil;
    id fc = nil;
    @try { fc = object_getIvar(obj, fcIvar); } @catch (__unused id e) { return nil; }
    if (![fc isKindOfClass:[NSDictionary class]]) return nil;
    id val = ((NSDictionary *)fc)[key];
    if (!val || [val isKindOfClass:[NSNull class]]) return nil;
    return val;
}

@implementation SCIDashParser

// Looks like XML DASH manifest or a URL to one.
static BOOL sciLooksLikeManifest(id val) {
    if (![val isKindOfClass:[NSString class]]) return NO;
    NSString *s = (NSString *)val;
    if (s.length < 10) return NO;
    NSString *head = [s substringToIndex:MIN((NSUInteger)16, s.length)];
    return [head containsString:@"<MPD"] || [head containsString:@"<?xml"]
        || [head hasPrefix:@"http"];
}

// Walk a fieldCache dict looking for any key containing "dash" or "manifest".
static NSString *sciScanDictForManifest(NSDictionary *dict, NSString *path, int depth) {
    if (depth > 3 || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    for (NSString *k in dict) {
        id v = dict[k];
        NSString *lk = k.lowercaseString;
        if (([lk containsString:@"dash"] || [lk containsString:@"manifest"]) && sciLooksLikeManifest(v)) {
            return v;
        }
        if ([v isKindOfClass:[NSDictionary class]]) {
            NSString *found = sciScanDictForManifest(v, [NSString stringWithFormat:@"%@/%@", path, k], depth + 1);
            if (found) return found;
        } else if ([v isKindOfClass:[NSArray class]]) {
            for (id item in (NSArray *)v) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    NSString *found = sciScanDictForManifest(item, [NSString stringWithFormat:@"%@/%@[]", path, k], depth + 1);
                    if (found) return found;
                }
            }
        }
    }
    return nil;
}

static NSDictionary *sciFieldCacheDict(id obj) {
    if (!obj) return nil;
    Ivar fcIvar = NULL;
    @try {
        for (Class c = [obj class]; c && !fcIvar; c = class_getSuperclass(c)) {
            fcIvar = class_getInstanceVariable(c, "_fieldCache");
        }
    } @catch (__unused id e) { return nil; }
    if (!fcIvar) return nil;
    id fc = nil;
    @try { fc = object_getIvar(obj, fcIvar); } @catch (__unused id e) { return nil; }
    return [fc isKindOfClass:[NSDictionary class]] ? fc : nil;
}

// Coerce an arbitrary object (NSString or NSData) into a manifest string.
static NSString *sciToManifestString(id val) {
    if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 10) return val;
    if ([val isKindOfClass:[NSData class]] && [(NSData *)val length] > 10) {
        NSString *s = [[NSString alloc] initWithData:(NSData *)val encoding:NSUTF8StringEncoding];
        if (s.length > 10) return s;
    }
    return nil;
}

+ (NSString *)dashManifestForMedia:(id)media {
    if (!media) return nil;

    NSArray *keys = @[@"video_dash_manifest", @"dash_manifest",
                      @"video_dash_manifest_url", @"dash_manifest_url"];

    // Direct hits on the media's fieldCache (older builds).
    for (NSString *key in keys) {
        id val = sciDashFieldCache(media, key);
        if (sciLooksLikeManifest(val)) return val;
    }

    // IGBaseMedia -videoDashManifest (used through IG v440ish).
    @try {
        if ([media respondsToSelector:@selector(videoDashManifest)]) {
            id val = ((id(*)(id, SEL))objc_msgSend)(media, @selector(videoDashManifest));
            NSString *str = sciToManifestString(val);
            if (sciLooksLikeManifest(str)) return str;
        }
    } @catch (__unused id e) {}

    // Nested IGVideo — both fieldCache + the new -dashManifestData NSData getter.
    id video = nil;
    @try {
        if ([media respondsToSelector:@selector(video)]) {
            video = ((id(*)(id, SEL))objc_msgSend)(media, @selector(video));
        }
    } @catch (__unused id e) { video = nil; }
    if (video) {
        for (NSString *key in keys) {
            id val = sciDashFieldCache(video, key);
            if (sciLooksLikeManifest(val)) return val;
        }
        @try {
            if ([video respondsToSelector:@selector(dashManifestData)]) {
                id val = ((id(*)(id, SEL))objc_msgSend)(video, @selector(dashManifestData));
                NSString *str = sciToManifestString(val);
                if (sciLooksLikeManifest(str)) return str;
            }
        } @catch (__unused id e) {}
        // Direct ivar read as last resort (handles future property removals).
        @try {
            Ivar iv = NULL;
            for (Class c = [video class]; c && !iv; c = class_getSuperclass(c))
                iv = class_getInstanceVariable(c, "_dashManifestData");
            if (iv) {
                id val = object_getIvar(video, iv);
                NSString *str = sciToManifestString(val);
                if (sciLooksLikeManifest(str)) return str;
            }
        } @catch (__unused id e) {}
    }

    // Wider scan: walk the fieldCache dict recursively for any key containing
    // "dash" or "manifest".
    NSDictionary *fc = sciFieldCacheDict(media);
    if (fc) {
        NSString *found = sciScanDictForManifest(fc, @"fieldCache", 0);
        if (found) return found;

        // Last-ditch manifest hunt via iterative stack (no recursion,
        // no block self-capture).
        NSMutableArray *stack = [NSMutableArray arrayWithObject:@[fc, @"fieldCache", @(0)]];
        NSString *bigManifest = nil;
        while (stack.count) {
            NSArray *frame = stack.lastObject; [stack removeLastObject];
            id obj = frame[0];
            NSString *path = frame[1];
            int depth = [frame[2] intValue];
            if (depth > 4) continue;
            if ([obj isKindOfClass:[NSDictionary class]]) {
                for (NSString *k in obj) {
                    [stack addObject:@[obj[k], [NSString stringWithFormat:@"%@/%@", path, k], @(depth + 1)]];
                }
            } else if ([obj isKindOfClass:[NSArray class]]) {
                NSUInteger i = 0;
                for (id item in obj) {
                    [stack addObject:@[item, [NSString stringWithFormat:@"%@[%lu]", path, (unsigned long)i++], @(depth + 1)]];
                }
            } else if ([obj isKindOfClass:[NSString class]]) {
                NSString *s = obj;
                if (s.length > 300) {
                    NSString *head = [s substringToIndex:MIN((NSUInteger)32, s.length)];
                    if (!bigManifest && ([head containsString:@"<MPD"] || [head containsString:@"<?xml"])) {
                        bigManifest = s;
                    }
                }
            }
        }
        if (bigManifest) return bigManifest;
        NSLog(@"[RyukGram][Dash] no manifest found; top-level keys=%@", [[fc allKeys] componentsJoinedByString:@","]);
    }

    return nil;
}

+ (NSArray<SCIDashRepresentation *> *)parseManifest:(NSString *)xmlString {
    if (!xmlString.length) return @[];

    NSMutableArray<SCIDashRepresentation *> *results = [NSMutableArray array];

    NSError *err = nil;

    // AdaptationSet blocks (handles both contentType= and mimeType= patterns)
    NSRegularExpression *adaptRE = [NSRegularExpression
        regularExpressionWithPattern:@"(<AdaptationSet[^>]*>)(.*?)</AdaptationSet>"
        options:NSRegularExpressionDotMatchesLineSeparators error:&err];
    if (err) return @[];

    NSRegularExpression *ctRE = [NSRegularExpression
        regularExpressionWithPattern:@"contentType=\"(video|audio)\"" options:NSRegularExpressionCaseInsensitive error:nil];
    NSRegularExpression *mtRE = [NSRegularExpression
        regularExpressionWithPattern:@"mimeType=\"(video|audio)/[^\"]*\"" options:NSRegularExpressionCaseInsensitive error:nil];

    NSRegularExpression *repRE = [NSRegularExpression
        regularExpressionWithPattern:@"<Representation[^>]*>"
        options:0 error:nil];

    NSRegularExpression *baseURLRE = [NSRegularExpression
        regularExpressionWithPattern:@"<BaseURL>(.*?)</BaseURL>"
        options:0 error:nil];

    NSRegularExpression *bwRE = [NSRegularExpression
        regularExpressionWithPattern:@"bandwidth=\"(\\d+)\"" options:0 error:nil];
    NSRegularExpression *widthRE = [NSRegularExpression
        regularExpressionWithPattern:@"(?:^|\\s)width=\"(\\d+)\"" options:0 error:nil];
    NSRegularExpression *heightRE = [NSRegularExpression
        regularExpressionWithPattern:@"(?:^|\\s)height=\"(\\d+)\"" options:0 error:nil];
    NSRegularExpression *labelRE = [NSRegularExpression
        regularExpressionWithPattern:@"FBQualityLabel=\"([^\"]+)\"" options:0 error:nil];
    NSRegularExpression *fpsRE = [NSRegularExpression
        regularExpressionWithPattern:@"frameRate=\"([0-9./]+)\"" options:0 error:nil];
    NSRegularExpression *codecsRE = [NSRegularExpression
        regularExpressionWithPattern:@"codecs=\"([^\"]+)\"" options:0 error:nil];

    [adaptRE enumerateMatchesInString:xmlString options:0
        range:NSMakeRange(0, xmlString.length)
        usingBlock:^(NSTextCheckingResult *adaptMatch, __unused NSMatchingFlags flags, __unused BOOL *stop) {

        NSString *adaptTag = [xmlString substringWithRange:[adaptMatch rangeAtIndex:1]];
        NSString *adaptBody = [xmlString substringWithRange:[adaptMatch rangeAtIndex:2]];

        NSString *contentType = nil;
        NSTextCheckingResult *ctMatch = [ctRE firstMatchInString:adaptTag options:0
            range:NSMakeRange(0, adaptTag.length)];
        if (ctMatch) {
            contentType = [[adaptTag substringWithRange:[ctMatch rangeAtIndex:1]] lowercaseString];
        } else {
            NSTextCheckingResult *mtMatch = [mtRE firstMatchInString:adaptTag options:0
                range:NSMakeRange(0, adaptTag.length)];
            if (mtMatch) {
                contentType = [[adaptTag substringWithRange:[mtMatch rangeAtIndex:1]] lowercaseString];
            }
        }
        if (!contentType) return;

        NSArray<NSTextCheckingResult *> *repMatches =
            [repRE matchesInString:adaptBody options:0 range:NSMakeRange(0, adaptBody.length)];
        NSArray<NSTextCheckingResult *> *urlMatches =
            [baseURLRE matchesInString:adaptBody options:0 range:NSMakeRange(0, adaptBody.length)];

        for (NSUInteger i = 0; i < repMatches.count && i < urlMatches.count; i++) {
            NSString *repTag = [adaptBody substringWithRange:repMatches[i].range];
            NSString *baseURL = [adaptBody substringWithRange:[urlMatches[i] rangeAtIndex:1]];

            if (!baseURL.length) continue;

            baseURL = [baseURL stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];

            SCIDashRepresentation *rep = [SCIDashRepresentation new];
            rep.url = [NSURL URLWithString:baseURL];
            rep.contentType = contentType;

            NSTextCheckingResult *bwMatch = [bwRE firstMatchInString:repTag options:0
                range:NSMakeRange(0, repTag.length)];
            if (bwMatch) rep.bandwidth = [[repTag substringWithRange:[bwMatch rangeAtIndex:1]] integerValue];

            NSTextCheckingResult *wMatch = [widthRE firstMatchInString:repTag options:0
                range:NSMakeRange(0, repTag.length)];
            if (wMatch) rep.width = [[repTag substringWithRange:[wMatch rangeAtIndex:1]] integerValue];

            NSTextCheckingResult *hMatch = [heightRE firstMatchInString:repTag options:0
                range:NSMakeRange(0, repTag.length)];
            if (hMatch) rep.height = [[repTag substringWithRange:[hMatch rangeAtIndex:1]] integerValue];

            NSTextCheckingResult *fpsMatch = [fpsRE firstMatchInString:repTag options:0
                range:NSMakeRange(0, repTag.length)];
            if (fpsMatch) {
                NSString *raw = [repTag substringWithRange:[fpsMatch rangeAtIndex:1]];
                NSArray *parts = [raw componentsSeparatedByString:@"/"];
                if (parts.count == 2) {
                    float num = [parts[0] floatValue], den = [parts[1] floatValue];
                    if (den > 0) rep.frameRate = num / den;
                } else {
                    rep.frameRate = [raw floatValue];
                }
            }
            NSTextCheckingResult *codecsMatch = [codecsRE firstMatchInString:repTag options:0
                range:NSMakeRange(0, repTag.length)];
            if (codecsMatch) rep.codecs = [repTag substringWithRange:[codecsMatch rangeAtIndex:1]];

            // Quality label from shorter dimension (1080x1920 → "1080p")
            if (rep.width > 0 && rep.height > 0) {
                NSInteger shortSide = MIN(rep.width, rep.height);
                rep.qualityLabel = [NSString stringWithFormat:@"%ldp", (long)shortSide];
            } else if (rep.height > 0) {
                rep.qualityLabel = [NSString stringWithFormat:@"%ldp", (long)rep.height];
            } else {
                NSTextCheckingResult *lMatch = [labelRE firstMatchInString:repTag options:0
                    range:NSMakeRange(0, repTag.length)];
                if (lMatch) rep.qualityLabel = [repTag substringWithRange:[lMatch rangeAtIndex:1]];
            }

            if (rep.url) [results addObject:rep];
        }
    }];

    return [results copy];
}

+ (SCIDashRepresentation *)bestVideoFromRepresentations:(NSArray<SCIDashRepresentation *> *)reps {
    return [[self videoRepresentations:reps] firstObject];
}

+ (SCIDashRepresentation *)bestAudioFromRepresentations:(NSArray<SCIDashRepresentation *> *)reps {
    SCIDashRepresentation *best = nil;
    for (SCIDashRepresentation *r in reps) {
        if (![r.contentType isEqualToString:@"audio"]) continue;
        if (!best || r.bandwidth > best.bandwidth) best = r;
    }
    return best;
}

+ (NSArray<SCIDashRepresentation *> *)videoRepresentations:(NSArray<SCIDashRepresentation *> *)reps {
    NSMutableArray *videos = [NSMutableArray array];
    for (SCIDashRepresentation *r in reps) {
        if ([r.contentType isEqualToString:@"video"]) [videos addObject:r];
    }
    return [videos sortedArrayUsingComparator:^NSComparisonResult(SCIDashRepresentation *a, SCIDashRepresentation *b) {
        return [@(b.bandwidth) compare:@(a.bandwidth)]; // descending
    }];
}

+ (SCIDashRepresentation *)representationForQuality:(SCIVideoQuality)quality
                                fromRepresentations:(NSArray<SCIDashRepresentation *> *)reps {
    NSArray *sorted = [self videoRepresentations:reps];
    if (!sorted.count) return nil;

    switch (quality) {
        case SCIVideoQualityHighest: return sorted.firstObject;
        case SCIVideoQualityLowest: return sorted.lastObject;
        case SCIVideoQualityMedium: return sorted[sorted.count / 2];
        case SCIVideoQualityAsk: return sorted.firstObject; // caller handles the picker
    }
    return sorted.firstObject;
}

@end
