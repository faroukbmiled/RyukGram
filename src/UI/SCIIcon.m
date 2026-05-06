#import "SCIIcon.h"
#import "../Localization/SCILocalization.h"

#import <math.h>

// MARK: - Friendly map

// Friendly keys + SF aliases → FB catalog candidates (first hit wins).
static NSDictionary<NSString *, NSArray<NSString *> *> *SCIIconFriendlyMap(void) {
    static NSDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            // Friendly keys
            @"feed":         @[@"ig_icon_feeds_outline_24"],
            @"feed_filled":  @[@"ig_icon_feeds_filled_24"],
            @"story":        @[@"ig_icon_story_pano_outline_24", @"ig_icon_story_outline_24"],
            @"reels":        @[@"ig_icon_reels_pano_prism_outline_24", @"ig_icon_reels_prism_outline_24", @"ig_icon_reels_outline_24"],
            @"messages":     @[@"ig_icon_direct_prism_outline_24", @"ig_icon_direct_pano_outline_24", @"ig_icon_direct_outline_24"],
            @"profile":      @[@"ig_icon_user_circle_prism_outline_24", @"ig_icon_user_circle_pano_outline_24"],
            @"settings":     @[@"ig_icon_settings_pano_outline_24", @"ig_icon_settings_outline_24"],
            @"settings_filled": @[@"ig_icon_settings_filled_24"],
            @"info":         @[@"ig_icon_info_pano_outline_24", @"ig_icon_info_outline_24"],
            @"check":        @[@"ig_icon_check_outline_24"],
            @"download":     @[@"ig_icon_download_outline_24"],
            @"download_filled": @[@"ig_icon_download_filled_24"],
            @"eye":          @[@"ig_icon_eye_outline_24"],
            @"eye_filled":   @[@"ig_icon_eye_filled_24"],
            @"eye_off":      @[@"ig_icon_eye_off_pano_outline_24"],
            @"eye_off_filled": @[@"ig_icon_eye_off_filled_24"],
            @"green_screen": @[@"ig_icon_green_screen_outline_24"],
            @"moon":         @[@"ig_icon_moon_outline_24"],
            @"instagram":    @[@"bcn_instagram_outline_24"],
            @"layout":       @[@"ig_icon_layout_outline_24"],
            @"location_arrow": @[@"ig_icon_location_arrow_approximate_filled_24", @"ig_icon_location_arrow_filled_24"],
            @"share":        @[@"ig_icon_share_pano_outline_24"],
            @"users":        @[@"ig_icon_users_prism_outline_24"],
            @"heart":        @[@"ig_icon_heart_pano_outline_24", @"ig_icon_heart_outline_24"],
            @"heart_filled": @[@"ig_icon_heart_filled_24"],
            @"home":         @[@"ig_icon_home_pano_prism_outline_24", @"ig_icon_home_prism_outline_24"],
            @"search":       @[@"ig_icon_search_pano_outline_24", @"ig_icon_search_outline_24"],
            @"camera":       @[@"ig_icon_camera_outline_24"],
            @"trash":        @[@"bcn_trash-can_outline_24"],
            @"edit":         @[@"ig_icon_edit_outline_24"],
            @"copy":         @[@"bcn_copy_outline_24"],
            @"link":         @[@"ig_icon_link_outline_24"],
            @"lock":         @[@"ig_icon_lock_filled_24"],
            @"unlock":       @[@"ig_icon_unlock_prism_outline_24", @"ig_icon_unlock_filled_24"],
            @"more":         @[@"ig_icon_more_horizontal_outline_24"],
            @"plus":         @[@"ig_icon_add_pano_outline_24", @"ig_icon_add_outline_24"],
            @"xmark":        @[@"ig_icon_x_pano_outline_24"],
            @"sort":         @[@"ig_icon_sort_pano_outline_24"],
            @"calendar":     @[@"ig_icon_calendar_outline_24"],
            @"toolbox":      @[@"ig_icon_toolbox_outline_24"],
            @"key":          @[@"ig_icon_key_outline_24"],
            @"interface":    @[@"ig_icon_device_phone_pano_outline_24", @"ig_icon_device_phone_prism_outline_24"],
            @"circle_check": @[@"ig_icon_circle_check_outline_24"],
            @"circle_check_filled": @[@"ig_icon_circle_check_pano_filled_24", @"ig_icon_circle_check_filled_24"],
            @"save":         @[@"ig_icon_save_outline_24"],
            @"save_filled":  @[@"ig_icon_save_filled_24"],
            @"scan_nametag": @[@"ig_icon_scan_nametag_pano_outline_24"],
            @"location":     @[@"ig_icon_location_map_outline_24", @"ig_icon_location_outline_24"],
            @"cloud":        @[@"ig_icon_app_icloud_outline_24"],
            @"sliders":      @[@"ig_icon_sliders_pano_outline_24", @"ig_icon_sliders_outline_24"],
            @"insights":     @[@"ig_icon_insights_pano_outline_24", @"ig_icon_insights_outline_24"],
            @"shield":       @[@"ig_icon_shield_pano_outline_24", @"ig_icon_shield_outline_24"],
            @"history":      @[@"ig_icon_history_pano_outline_24", @"ig_icon_history_outline_24"],
            @"globe":        @[@"bcn_globe_outline_24"],
            @"action_button": @[@"ig_icon_app_instants_archive_outline_24"],
            @"hashtag":      @[@"bcn_hashtag_outline_24"],
            @"magnifyingglass": @[@"bcn_magnifying-glass-heavy_outline_24"],
            @"document":     @[@"ig_icon_document_lined_prism_outline_24"],
            @"photo":        @[@"ig_icon_photo_outline_24"],
            @"photo_filled": @[@"ig_icon_photo_filled_24"],
            @"photo_gen_ai": @[@"ig_icon_photo_gen_ai_outline_24"],
            @"photo_gallery": @[@"ig_icon_photo_gallery_outline_24"],
            @"mention":      @[@"ig_icon_story_mention_pano_outline_24"],
            @"arrow_up":     @[@"ig_icon_arrow_up_outline_24"],
            @"arrow_down":   @[@"ig_icon_arrow_down_outline_24"],
            @"arrow_left":   @[@"ig_icon_arrow_left_outline_24"],
            @"arrow_right":  @[@"ig_icon_arrow_right_outline_24"],
            @"arrow_cw":     @[@"ig_icon_arrow_cw_outline_24"],
            @"arrow_ccw":    @[@"ig_icon_arrow_ccw_outline_24"],
            @"expand":       @[@"ig_icon_fit_outline_24"],

            // SF-symbol-name aliases (auto-substitute at unmapped call sites)
            @"gear":         @[@"ig_icon_settings_pano_outline_24", @"ig_icon_settings_outline_24"],
            @"gearshape":    @[@"ig_icon_settings_pano_outline_24", @"ig_icon_settings_outline_24"],
            @"gearshape.fill": @[@"ig_icon_settings_filled_24"],
            @"gearshape.2":  @[@"ig_icon_toolbox_outline_24"],
            @"square.and.arrow.up":   @[@"ig_icon_share_pano_outline_24"],
            @"square.and.arrow.down": @[@"ig_icon_download_outline_24"],
            @"arrow.down.circle":     @[@"ig_icon_download_outline_24"],
            @"arrow.up.circle":       @[@"ig_icon_share_pano_outline_24"],
            @"doc.on.doc":   @[@"bcn_copy_outline_24"],
            // `at` deliberately absent — keeps mention button + action menu on SF.
            @"checkmark":    @[@"ig_icon_check_outline_24"],
            @"checkmark.circle":       @[@"ig_icon_circle_check_outline_24"],
            @"checkmark.circle.fill":  @[@"ig_icon_circle_check_pano_filled_24", @"ig_icon_circle_check_filled_24"],
            @"info.circle":  @[@"ig_icon_info_pano_outline_24", @"ig_icon_info_outline_24"],
            @"lock.fill":    @[@"ig_icon_lock_filled_24"],
            @"lock.open.fill": @[@"ig_icon_unlock_prism_outline_24", @"ig_icon_unlock_filled_24"],
            @"person.crop.circle": @[@"ig_icon_user_circle_prism_outline_24"],
            @"person.circle.fill": @[@"ig_icon_user_circle_prism_filled_24", @"ig_icon_user_circle_filled_24"],
            @"arrow.counterclockwise":        @[@"ig_icon_arrow_ccw_outline_24"],
            @"arrow.counterclockwise.circle": @[@"ig_icon_history_pano_outline_24", @"ig_icon_history_outline_24"],
            @"arrow.clockwise":               @[@"ig_icon_arrow_cw_outline_24"],
            @"arrow.clockwise.circle.fill":   @[@"ig_icon_history_pano_outline_24", @"ig_icon_history_outline_24"],
            @"clock.arrow.circlepath":        @[@"ig_icon_history_pano_outline_24", @"ig_icon_history_outline_24"],
            @"archivebox":   @[@"ig_icon_document_lined_prism_outline_24"],
            @"arrow.up.arrow.down": @[@"ig_icon_sort_pano_outline_24"],
            @"arrow.up":     @[@"ig_icon_arrow_up_outline_24"],
            @"arrow.down":   @[@"ig_icon_arrow_down_outline_24"],
            @"trash.fill":   @[@"bcn_trash-can_outline_24"],
            @"number":       @[@"bcn_hashtag_outline_24"],
            @"photo.on.rectangle.angled": @[@"ig_icon_photo_gallery_outline_24"],
            @"photo.badge.checkmark":      @[@"ig_icon_photo_gen_ai_outline_24"],
            @"photo.badge.checkmark.fill": @[@"ig_icon_photo_gen_ai_outline_24"],
            @"heart.fill":   @[@"ig_icon_heart_filled_24"],
            @"hand.draw.fill": @[@"ig_icon_layout_outline_24"],
            @"rectangle.stack": @[@"ig_icon_feeds_outline_24"],
            @"film.stack":   @[@"ig_icon_reels_pano_prism_outline_24", @"ig_icon_reels_outline_24"],
            @"bubble.left.and.bubble.right": @[@"ig_icon_direct_prism_outline_24"],
            @"circle.dashed": @[@"ig_icon_story_pano_outline_24", @"ig_icon_story_outline_24"],
            @"tray.and.arrow.down": @[@"ig_icon_download_filled_24"],
            @"arrow.up.left.and.arrow.down.right": @[@"ig_icon_fit_outline_24"],
            @"list.bullet.rectangle": @[@"ig_icon_app_instants_archive_outline_24"],
            @"eye.fill":     @[@"ig_icon_eye_filled_24"],
            @"eye.slash":    @[@"ig_icon_eye_off_pano_outline_24"],
            @"eye.slash.fill": @[@"ig_icon_eye_off_filled_24"],
        };
    });
    return map;
}

// MARK: - Internals

static NSBundle *SCIIconFBBundle(void) {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks/FBSharedFramework.framework"];
        bundle = [NSBundle bundleWithPath:path];
    });
    return bundle;
}

// Down-only scale.
static UIImage *SCIIconScale(UIImage *image, CGFloat pointSize) {
    if (!image || pointSize <= 0) return image;
    CGFloat maxDim = MAX(image.size.width, image.size.height);
    if (maxDim <= pointSize + 0.01) return image;

    CGFloat ratio = pointSize / maxDim;
    CGSize newSize = CGSizeMake(round(image.size.width * ratio), round(image.size.height * ratio));
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = image.scale;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:newSize format:fmt];
    UIImage *scaled = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    }];
    return [scaled imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage *SCIIconResolveFB(NSString *name) {
    if (name.length == 0) return nil;
    NSBundle *bundle = SCIIconFBBundle();
    if (!bundle) return nil;

    NSArray<NSString *> *candidates = SCIIconFriendlyMap()[name.lowercaseString] ?: @[name];
    for (NSString *raw in candidates) {
        UIImage *img = [UIImage imageNamed:raw inBundle:bundle compatibleWithTraitCollection:nil];
        if (img) return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return nil;
}

static UIImage *SCIIconResolveSF(NSString *name, UIImageSymbolConfiguration *cfg) {
    if (name.length == 0) return nil;
    return cfg ? [UIImage systemImageNamed:name withConfiguration:cfg]
               : [UIImage systemImageNamed:name];
}

static UIImage *SCIIconResolveBundlePNG(NSString *name) {
    NSBundle *bundle = SCILocalizationBundle();
    if (!bundle) return nil;
    UIImage *img = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImageSymbolConfiguration *SCIIconConfig(CGFloat pointSize, UIImageSymbolWeight weight) {
    if (pointSize > 0) return [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    if (weight != UIImageSymbolWeightUnspecified && weight != UIImageSymbolWeightRegular)
        return [UIImageSymbolConfiguration configurationWithWeight:weight];
    return nil;
}

// MARK: - Public

@implementation SCIIcon

+ (UIImage *)imageNamed:(NSString *)name {
    return [self imageNamed:name configuration:nil];
}

+ (UIImage *)imageNamed:(NSString *)name pointSize:(CGFloat)pointSize {
    return [self imageNamed:name pointSize:pointSize weight:UIImageSymbolWeightRegular];
}

+ (UIImage *)imageNamed:(NSString *)name pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight {
    UIImage *fb = SCIIconResolveFB(name);
    if (fb) return SCIIconScale(fb, pointSize);

    UIImage *sf = SCIIconResolveSF(name, SCIIconConfig(pointSize, weight));
    return sf ?: SCIIconResolveBundlePNG(name);
}

+ (UIImage *)imageNamed:(NSString *)name configuration:(UIImageSymbolConfiguration *)config {
    UIImage *fb = SCIIconResolveFB(name);
    if (fb) return fb;

    UIImage *sf = SCIIconResolveSF(name, config);
    return sf ?: SCIIconResolveBundlePNG(name);
}

+ (UIImage *)fbImageNamed:(NSString *)name {
    return SCIIconResolveFB(name);
}

+ (UIImage *)fbImageNamed:(NSString *)name pointSize:(CGFloat)pointSize {
    return SCIIconScale(SCIIconResolveFB(name), pointSize);
}

+ (UIImage *)sfImageNamed:(NSString *)name {
    return SCIIconResolveSF(name, nil);
}

+ (UIImage *)sfImageNamed:(NSString *)name pointSize:(CGFloat)pointSize {
    return [self sfImageNamed:name pointSize:pointSize weight:UIImageSymbolWeightRegular];
}

+ (UIImage *)sfImageNamed:(NSString *)name pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight {
    return SCIIconResolveSF(name, SCIIconConfig(pointSize, weight));
}

+ (UIImage *)sfImageNamed:(NSString *)name configuration:(UIImageSymbolConfiguration *)config {
    return SCIIconResolveSF(name, config);
}

@end
