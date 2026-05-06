#import "SCIAssetUtils.h"
#import "../UI/SCIIcon.h"

// Gallery uses SF symbols only — IG asset names mapped here. Anything missing
// from the table falls back to SCIIcon's hybrid resolver.
static NSString *SCISFForIGName(NSString *name) {
    if (!name.length) return nil;
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            // Generic / chrome
            @"more":          @"ellipsis",
            @"settings":      @"gearshape",
            @"xmark":         @"xmark",
            @"circle_check":  @"checkmark.circle",
            @"backspace":     @"delete.left",
            @"external_link": @"arrow.up.right.square",
            @"copy":          @"doc.on.doc",
            @"copy_filled":   @"doc.on.doc.fill",
            @"link":          @"link",
            @"text":          @"textformat",
            @"caption":       @"text.quote",
            @"key":           @"number",
            @"username":      @"at",
            @"users":         @"person.2",
            @"lock":          @"lock",
            @"unlock":        @"lock.open",
            @"profile":       @"person.crop.circle",

            // Media
            @"photo":         @"photo",
            @"photo_filled":  @"photo.fill",
            @"video":         @"video",
            @"video_filled":  @"video.fill",
            @"media":         @"photo.on.rectangle",
            @"media_empty":   @"photo.on.rectangle.angled",
            @"photo_gallery": @"photo.on.rectangle.angled",

            // Sources
            @"feed":          @"rectangle.stack",
            @"story":         @"circle.dashed",
            @"stories":       @"circle.dashed",
            @"reels":         @"film.stack",
            @"reel":          @"film",
            @"messages":      @"bubble.left.and.bubble.right",
            @"green_screen":  @"person.fill.viewfinder",

            // Actions
            @"share":         @"square.and.arrow.up",
            @"download":      @"square.and.arrow.down",
            @"download_filled": @"square.and.arrow.down.fill",
            @"trash":         @"trash",
            @"delete":        @"trash",
            @"folder":        @"folder",
            @"folder_move":   @"folder.badge.gearshape",
            @"heart":         @"heart",
            @"heart_filled":  @"heart.fill",
            @"favorite":      @"star",
            @"favorite_filled": @"star.fill",
            @"search":        @"magnifyingglass",
            @"filter":        @"line.3.horizontal.decrease.circle",
            @"sort":          @"arrow.up.arrow.down",
            @"size_large":    @"arrow.up.arrow.down",
            @"size_small":    @"arrow.down.arrow.up",
            @"calendar":      @"calendar",
            @"list":          @"list.bullet",
            @"grid":          @"square.grid.2x2",

            // Status
            @"error_filled":  @"exclamationmark.triangle.fill",
            @"info":          @"info.circle",

            // Misc
            @"edit":              @"pencil",
            @"circle_check_filled": @"checkmark.circle.fill",
            @"save":              @"square.and.arrow.down",
            @"add":               @"plus",
            @"plus":              @"plus",
            @"close":             @"xmark",
        };
    });
    return map[name];
}

static UIImage *SCIResolvedSFImage(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight) {
    NSString *sf = SCISFForIGName(name);
    if (sf.length) {
        UIImage *img = [SCIIcon sfImageNamed:sf pointSize:pointSize weight:weight];
        if (img) return img;
    }
    // Treat the input as already-an-SF-symbol (e.g. "lock.fill").
    UIImage *direct = [SCIIcon sfImageNamed:name pointSize:pointSize weight:weight];
    if (direct) return direct;
    // Last resort: hybrid resolver (FB asset / bundle / SF).
    return [SCIIcon imageNamed:name pointSize:pointSize weight:weight];
}

@implementation SCIAssetUtils

+ (UIImage *)instagramIconNamed:(NSString *)name {
    return [self instagramIconNamed:name pointSize:17.0];
}

+ (UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize {
    return SCIResolvedSFImage(name, pointSize, UIImageSymbolWeightRegular);
}

+ (UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize renderingMode:(UIImageRenderingMode)renderingMode {
    UIImage *img = SCIResolvedSFImage(name, pointSize, UIImageSymbolWeightRegular);
    return [img imageWithRenderingMode:renderingMode];
}

+ (UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize source:(SCIAssetCatalogSource)source {
    return SCIResolvedSFImage(name, pointSize, UIImageSymbolWeightRegular);
}

+ (UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize source:(SCIAssetCatalogSource)source renderingMode:(UIImageRenderingMode)renderingMode {
    UIImage *img = SCIResolvedSFImage(name, pointSize, UIImageSymbolWeightRegular);
    return [img imageWithRenderingMode:renderingMode];
}

+ (UIImage *)resolvedImageNamed:(NSString *)name pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight source:(SCIResolvedImageSource)source renderingMode:(UIImageRenderingMode)renderingMode {
    if (!name.length) return nil;
    UIImage *img = (source == SCIResolvedImageSourceSystemSymbol)
        ? [SCIIcon sfImageNamed:name pointSize:pointSize weight:weight]
        : SCIResolvedSFImage(name, pointSize, weight);
    return [img imageWithRenderingMode:renderingMode];
}

+ (UIImage *)resolvedImageNamed:(NSString *)name fallbackSystemName:(NSString *)fallbackSystemName pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight source:(SCIResolvedImageSource)source renderingMode:(UIImageRenderingMode)renderingMode {
    UIImage *img = name.length ? SCIResolvedSFImage(name, pointSize, weight) : nil;
    if (!img && fallbackSystemName.length) {
        img = [SCIIcon sfImageNamed:fallbackSystemName pointSize:pointSize weight:weight];
    }
    return [img imageWithRenderingMode:renderingMode];
}

@end
