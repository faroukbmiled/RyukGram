#import "Utils.h"
#import "PhotoAlbum.h"
#import "Settings/TweakSettings.h"

@implementation SCIUtils

static NSDictionary *sciRegisteredDefaultsRef = nil;

+ (BOOL)getBoolPref:(NSString *)key {
    if (![key length]) return false;
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (v == nil) v = sciRegisteredDefaultsRef[key];
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v boolValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v boolValue];
    return false;
}
+ (double)getDoublePref:(NSString *)key {
    if (![key length]) return 0;
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (v == nil) v = sciRegisteredDefaultsRef[key];
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v doubleValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v doubleValue];
    return 0;
}
+ (NSString *)getStringPref:(NSString *)key {
    if (![key length]) return @"";
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (v == nil) v = sciRegisteredDefaultsRef[key];
    if (![v isKindOfClass:[NSString class]]) return @"";
    return v;
}

+ (NSDictionary<NSString *, id> *)sciRegisteredDefaults { return sciRegisteredDefaultsRef ?: @{}; }
+ (void)setSciRegisteredDefaults:(NSDictionary<NSString *, id> *)defaults {
    sciRegisteredDefaultsRef = [defaults copy];
}

+ (_Bool)liquidGlassEnabledBool:(_Bool)fallback {
    BOOL setting = [SCIUtils getBoolPref:@"liquid_glass_surfaces"];
    return setting ? true : fallback;
}

// Displaying View Controllers
+ (void)showQuickLookVC:(NSArray<id> *)items {
    UIViewController *topVC = topMostController();
    if (!topVC) {
        NSLog(@"[RyukGram] No view controller available to present QuickLook");
        return;
    }

    QLPreviewController *previewController = [[QLPreviewController alloc] init];
    QuickLookDelegate *quickLookDelegate = [[QuickLookDelegate alloc] initWithPreviewItemURLs:items];

    previewController.dataSource = quickLookDelegate;

    [topVC presentViewController:previewController animated:true completion:nil];
}
+ (void)showShareVC:(id)item {
    UIViewController *topVC = topMostController();
    if (!topVC) {
        NSLog(@"[RyukGram] No view controller available to present share sheet");
        return;
    }

    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    if (is_iPad()) {
        acVC.popoverPresentationController.sourceView = topVC.view;
        acVC.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2.0, topVC.view.bounds.size.height / 2.0, 1.0, 1.0);
    }

    // If the user picks "Save to Photos" from the share sheet, route the new
    // asset into the RyukGram album via a one-shot photo library observer.
    if ([self getBoolPref:@"save_to_ryukgram_album"]) {
        [SCIPhotoAlbum watchForNextSavedAsset];
    }

    [topVC presentViewController:acVC animated:true completion:nil];
}
+ (void)showSettingsVC:(UIWindow *)window {
    UIViewController *rootController = [window rootViewController];
    SCISettingsViewController *settingsViewController = [SCISettingsViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    if ([SCIUtils getBoolPref:@"settings_pause_playback"])
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;

    [rootController presentViewController:navigationController animated:YES completion:nil];
}

// Open settings and push straight into a named top-level entry (e.g. "Messages").
+ (void)showSettingsVC:(UIWindow *)window atTopLevelEntry:(NSString *)entryTitle {
    UIViewController *rootController = [window rootViewController];
    while (rootController.presentedViewController) rootController = rootController.presentedViewController;
    SCISettingsViewController *root = [SCISettingsViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    if ([SCIUtils getBoolPref:@"settings_pause_playback"])
        nav.modalPresentationStyle = UIModalPresentationFullScreen;

    NSArray *targetNavSections = nil;
    for (NSDictionary *section in [SCITweakSettings sections]) {
        for (SCISetting *row in section[@"rows"]) {
            if (row.type == SCITableCellNavigation && [row.title isEqualToString:entryTitle]) {
                targetNavSections = row.navSections;
                break;
            }
        }
        if (targetNavSections) break;
    }

    if (targetNavSections) {
        SCISettingsViewController *child = [[SCISettingsViewController alloc]
            initWithTitle:entryTitle sections:targetNavSections reduceMargin:NO];
        child.title = entryTitle;
        [nav pushViewController:child animated:NO];
    }

    [rootController presentViewController:nav animated:YES completion:nil];
}

// Colours
+ (UIColor *)SCIColor_Primary {
    return [UIColor colorWithRed:0/255.0 green:152/255.0 blue:254/255.0 alpha:1];
};

// Errors
+ (NSError *)errorWithDescription:(NSString *)errorDesc {
    return [self errorWithDescription:errorDesc code:1];
}
+ (NSError *)errorWithDescription:(NSString *)errorDesc code:(NSInteger)errorCode {
    NSError *error = [ NSError errorWithDomain:@"com.socuul.scinsta" code:errorCode userInfo:@{ NSLocalizedDescriptionKey: errorDesc } ];
    return error;
}

+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc {
    return [self showErrorHUDWithDescription:errorDesc dismissAfterDelay:4.0];
}
+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc dismissAfterDelay:(CGFloat)dismissDelay {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = errorDesc;
    hud.indicatorView = [[JGProgressHUDErrorIndicatorView alloc] init];

    UIView *hudView = topMostController().view;
    if (!hudView) hudView = [UIApplication sharedApplication].keyWindow;
    if (hudView) {
        [hud showInView:hudView];
        [hud dismissAfterDelay:dismissDelay];
    } else {
        NSLog(@"[RyukGram] No valid view for error HUD: %@", errorDesc);
    }

    return hud;
}

// Media

// fieldCache fallback — reads the Pando-backed dict directly for when
// IG's exposed property accessors break between versions.
static id sciFieldCacheValue(id obj, NSString *key) {
    if (!obj || !key.length) return nil;
    Ivar iv = NULL;
    for (Class c = [obj class]; c && !iv; c = class_getSuperclass(c))
        iv = class_getInstanceVariable(c, "_fieldCache");
    if (!iv) return nil;
    @try {
        NSDictionary *dict = object_getIvar(obj, iv);
        if (![dict isKindOfClass:[NSDictionary class]]) return nil;
        return dict[key];
    } @catch (__unused id e) { return nil; }
}

+ (NSURL *)getPhotoUrl:(IGPhoto *)photo {
    if (!photo) return nil;
    @try {
        if ([photo respondsToSelector:@selector(imageURLForWidth:)]) {
            NSURL *url = [photo imageURLForWidth:100000.00];
            if (url) return url;
        }
    } @catch (__unused NSException *e) {}
    return nil;
}

+ (NSURL *)getPhotoUrlForMedia:(IGMedia *)media {
    if (!media) return nil;

    // fieldCache first — IGPhoto selectors crash on newer IG builds.
    @try {
        NSDictionary *imageVersions = sciFieldCacheValue(media, @"image_versions2");
        NSArray *candidates = [imageVersions isKindOfClass:[NSDictionary class]] ? imageVersions[@"candidates"] : nil;
        if ([candidates isKindOfClass:[NSArray class]] && candidates.count) {
            NSDictionary *best = nil;
            NSInteger bestW = -1;
            for (id c in candidates) {
                if (![c isKindOfClass:[NSDictionary class]]) continue;
                NSInteger w = [[c objectForKey:@"width"] integerValue];
                if (w > bestW) { bestW = w; best = c; }
            }
            NSString *urlStr = best[@"url"] ?: [[candidates firstObject] objectForKey:@"url"];
            if ([urlStr isKindOfClass:[NSString class]] && urlStr.length) {
                return [NSURL URLWithString:urlStr];
            }
        }
    } @catch (__unused NSException *e) {}

    IGPhoto *photo = nil;
    @try {
        if ([media respondsToSelector:@selector(photo)]) photo = media.photo;
    } @catch (__unused NSException *e) {}
    if (photo) return [SCIUtils getPhotoUrl:photo];
    return nil;
}

+ (NSURL *)getVideoUrl:(IGVideo *)video {
    if (!video) return nil;

    @try {
        if ([video respondsToSelector:@selector(sortedVideoURLsBySize)]) {
            NSArray<NSDictionary *> *sorted = [video sortedVideoURLsBySize];
            NSString *urlString = [sorted.firstObject isKindOfClass:[NSDictionary class]] ? sorted.firstObject[@"url"] : nil;
            if ([urlString isKindOfClass:[NSString class]] && urlString.length) return [NSURL URLWithString:urlString];
        }
    } @catch (__unused NSException *e) {}

    @try {
        if ([video respondsToSelector:@selector(allVideoURLs)]) {
            id set = [video allVideoURLs];
            if ([set respondsToSelector:@selector(anyObject)]) {
                id obj = [set anyObject];
                if ([obj isKindOfClass:[NSURL class]]) {
                    NSString *abs = nil;
                    @try { abs = [(NSURL *)obj absoluteString]; } @catch (__unused NSException *e) {}
                    if (abs.length && ([abs hasPrefix:@"http"] || [abs hasPrefix:@"file:"])) {
                        return [NSURL URLWithString:abs];
                    }
                } else if ([obj isKindOfClass:[NSString class]]) {
                    NSString *s = (NSString *)obj;
                    if (s.length && ([s hasPrefix:@"http"] || [s hasPrefix:@"file:"])) return [NSURL URLWithString:s];
                }
            }
        }
    } @catch (__unused NSException *e) {}
    return nil;
}

+ (NSURL *)getVideoUrlForMedia:(IGMedia *)media {
    if (!media) return nil;

    // fieldCache first — IGVideo selectors crash on newer IG builds.
    @try {
        NSArray *versions = sciFieldCacheValue(media, @"video_versions");
        if ([versions isKindOfClass:[NSArray class]] && versions.count) {
            NSDictionary *best = nil;
            NSInteger bestType = -1;
            for (id v in versions) {
                if (![v isKindOfClass:[NSDictionary class]]) continue;
                NSInteger type = [[v objectForKey:@"type"] integerValue];
                if (type > bestType) { bestType = type; best = v; }
            }
            NSString *urlStr = best[@"url"] ?: [[versions firstObject] objectForKey:@"url"];
            if ([urlStr isKindOfClass:[NSString class]] && urlStr.length) {
                return [NSURL URLWithString:urlStr];
            }
        }
    } @catch (__unused NSException *e) {}

    IGVideo *video = nil;
    @try {
        if ([media respondsToSelector:@selector(video)]) video = media.video;
    } @catch (__unused NSException *e) {}
    if (video) return [SCIUtils getVideoUrl:video];
    return nil;
}

// View Controllers
+ (UIViewController *)viewControllerForView:(UIView *)view {
    NSString *viewDelegate = @"viewDelegate";
    if ([view respondsToSelector:NSSelectorFromString(viewDelegate)]) {
        return [view valueForKey:viewDelegate];
    }

    return nil;
}

+ (UIViewController *)viewControllerForAncestralView:(UIView *)view {
    NSString *_viewControllerForAncestor = @"_viewControllerForAncestor";
    if ([view respondsToSelector:NSSelectorFromString(_viewControllerForAncestor)]) {
        return [view valueForKey:_viewControllerForAncestor];
    }

    return nil;
}

+ (UIViewController *)nearestViewControllerForView:(UIView *)view {
    return [self viewControllerForView:view] ?: [self viewControllerForAncestralView:view];
}

// Functions
+ (NSString *)IGVersionString {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
};
+ (BOOL)isNotch {
    return [[[UIApplication sharedApplication] keyWindow] safeAreaInsets].bottom > 0;
};

+ (BOOL)existingLongPressGestureRecognizerForView:(UIView *)view {
    NSArray *allRecognizers = view.gestureRecognizers;

    for (UIGestureRecognizer *recognizer in allRecognizers) {
        if ([[recognizer class] isSubclassOfClass:[UILongPressGestureRecognizer class]]) {
            return YES;
        }
    }

    return NO;
}

// Alerts
+ (BOOL)showConfirmation:(void(^)(void))okHandler title:(NSString *)title {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:SCILocalized(@"Are you sure?") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Yes") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        okHandler();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"No!") style:UIAlertActionStyleCancel handler:nil]];

    [topMostController() presentViewController:alert animated:YES completion:nil];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler title:(NSString *)title {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:SCILocalized(@"Are you sure?") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Yes") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        okHandler();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"No!") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (cancelHandler != nil) {
            cancelHandler();
        }
    }]];

    [topMostController() presentViewController:alert animated:YES completion:nil];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler {
    return [self showConfirmation:okHandler title:nil];
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler {
    return [self showConfirmation:okHandler cancelHandler:cancelHandler title:nil];
}
+ (void)showRestartConfirmation {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:SCILocalized(@"Restart required") message:SCILocalized(@"You must restart the app to apply this change") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Restart") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Later") style:UIAlertActionStyleCancel handler:nil]];

    [topMostController() presentViewController:alert animated:YES completion:nil];
};

// Toasts
+ (void)showToastForDuration:(double)duration title:(NSString *)title {
    [SCIUtils showToastForDuration:duration title:title subtitle:nil];
}
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle {
    // Root VC
    Class rootVCClass = NSClassFromString(@"IGRootViewController");

    UIViewController *topMostVC = topMostController();
    if (![topMostVC isKindOfClass:rootVCClass]) return;

    IGRootViewController *rootVC = (IGRootViewController *)topMostVC;

    // Presenter
    IGActionableConfirmationToastPresenter *toastPresenter = [rootVC toastPresenter];
    if (toastPresenter == nil) return;

    // View Model
    Class modelClass = NSClassFromString(@"IGActionableConfirmationToastViewModel");
    IGActionableConfirmationToastViewModel *model = [modelClass new];
    
    [model setValue:title forKey:@"text_annotatedTitleText"];
    [model setValue:subtitle forKey:@"text_annotatedSubtitleText"];

    // Show new toast, after clearing existing one
    [toastPresenter hideAlert];
    [toastPresenter showAlertWithViewModel:model isAnimated:true animationDuration:duration presentationPriority:0 tapActionBlock:nil presentedHandler:nil dismissedHandler:nil];
}

// Math
+ (NSUInteger)decimalPlacesInDouble:(double)value {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:15]; // Allow enough digits for double precision
    [formatter setMinimumFractionDigits:0];
    [formatter setDecimalSeparator:@"."]; // Force dot for internal logic, then respect locale for final display if needed

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    // Find decimal separator
    NSRange decimalRange = [stringValue rangeOfString:formatter.decimalSeparator];

    if (decimalRange.location == NSNotFound) {
        return 0;
    } else {
        return stringValue.length - (decimalRange.location + decimalRange.length);
    }
}

// Ivars
+ (id)getIvarForObj:(id)obj name:(const char *)name {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return nil;

    return object_getIvar(obj, ivar);
}
+ (void)setIvarForObj:(id)obj name:(const char *)name value:(id)value {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return;

    object_setIvarWithStrongDefault(obj, ivar, value);
}

+ (id)activeUserSession {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            @try {
                id s = [w valueForKey:@"userSession"];
                if (s) return s;
            } @catch (__unused id e) {}
        }
    }
    return nil;
}

+ (NSString *)pkFromIGUser:(id)user {
    if (!user) return nil;
    Ivar pkIvar = NULL;
    for (Class c = [user class]; c && !pkIvar; c = class_getSuperclass(c)) {
        pkIvar = class_getInstanceVariable(c, "_pk");
    }
    if (!pkIvar) return nil;
    id pk = object_getIvar(user, pkIvar);
    return pk ? [pk description] : nil;
}

+ (NSString *)currentUserPK {
    id session = [self activeUserSession];
    if (!session) return nil;
    @try {
        id user = [session valueForKey:@"user"];
        return [self pkFromIGUser:user];
    } @catch (__unused id e) { return nil; }
}

@end