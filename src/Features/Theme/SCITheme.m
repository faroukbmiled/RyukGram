#import "SCITheme.h"

NSString *const SCIThemePrefMode     = @"theme_mode";
NSString *const SCIThemePrefForce    = @"theme_force";
NSString *const SCIThemePrefOLEDChat = @"theme_oled_chat";
NSString *const SCIThemePrefKeyboard = @"theme_keyboard";

static NSString *const SCIThemeMigrationFlag = @"theme_migrated_v1";

@implementation SCITheme

+ (SCIThemeMode)mode {
    return [self modeForKey:[self modeKey]];
}

+ (BOOL)forceTheme {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SCIThemePrefForce];
}

+ (NSString *)modeKey {
    NSString *raw = [[NSUserDefaults standardUserDefaults] stringForKey:SCIThemePrefMode];
    return raw.length ? raw : @"off";
}

+ (SCIThemeMode)modeForKey:(NSString *)key {
    if ([key isEqualToString:@"light"]) return SCIThemeModeLight;
    if ([key isEqualToString:@"dark"])  return SCIThemeModeDark;
    if ([key isEqualToString:@"oled"])  return SCIThemeModeOLED;
    return SCIThemeModeOff;
}

+ (BOOL)isSystemDark {
    // Key window can be nil during early launch — walk every connected scene.
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *win in ((UIWindowScene *)scene).windows) {
            return win.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
    }
    return UIScreen.mainScreen.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

+ (BOOL)effectiveDark {
    SCIThemeMode m = [self mode];
    if (m == SCIThemeModeOff) return [self isSystemDark];
    if ([self forceTheme]) return m != SCIThemeModeLight;
    return [self isSystemDark];
}

+ (BOOL)shouldOverrideAppearance {
    if ([self mode] == SCIThemeModeOff) return NO;
    return [self forceTheme];
}

+ (UIUserInterfaceStyle)overrideStyle {
    switch ([self mode]) {
        case SCIThemeModeLight: return UIUserInterfaceStyleLight;
        case SCIThemeModeDark:
        case SCIThemeModeOLED: return UIUserInterfaceStyleDark;
        default: return UIUserInterfaceStyleUnspecified;
    }
}

+ (BOOL)shouldRecolor {
    return [self mode] == SCIThemeModeOLED && [self effectiveDark];
}

+ (UIColor *)backgroundColor {
    return [UIColor blackColor];
}

+ (UIColor *)surfaceColor {
    // Alpha 0.89 dodges the >= 0.9 near-black gate so SCI*-owned cells stay
    // visible under the OLED recolor.
    return [UIColor colorWithWhite:0.08 alpha:0.89];
}

+ (BOOL)colorIsNearBlack:(UIColor *)color {
    if (!color) return NO;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return (a >= 0.9 && r < 0.13 && g < 0.13 && b < 0.13);
    }
    CGFloat w = 0;
    if ([color getWhite:&w alpha:&a]) {
        return (a >= 0.9 && w < 0.13);
    }
    return NO;
}

+ (UIColor *)colorFromHex:(NSString *)hex {
    if (hex.length == 0) return nil;
    NSString *s = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length != 6 && s.length != 8) return nil;
    unsigned int v = 0;
    if (![[NSScanner scannerWithString:s] scanHexInt:&v]) return nil;
    CGFloat r, g, b, a = 1.0;
    if (s.length == 6) {
        r = ((v >> 16) & 0xFF) / 255.0;
        g = ((v >>  8) & 0xFF) / 255.0;
        b = ( v        & 0xFF) / 255.0;
    } else {
        r = ((v >> 24) & 0xFF) / 255.0;
        g = ((v >> 16) & 0xFF) / 255.0;
        b = ((v >>  8) & 0xFF) / 255.0;
        a = ( v        & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

+ (NSString *)hexFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        if ([color getWhite:&w alpha:&a]) { r = g = b = w; }
    }
    int ri = (int)round(MAX(0.0, MIN(1.0, r)) * 255.0);
    int gi = (int)round(MAX(0.0, MIN(1.0, g)) * 255.0);
    int bi = (int)round(MAX(0.0, MIN(1.0, b)) * 255.0);
    return [NSString stringWithFormat:@"#%02X%02X%02X", ri, gi, bi];
}

+ (void)resetToDefaults {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:@"off" forKey:SCIThemePrefMode];
    [d setBool:NO       forKey:SCIThemePrefForce];
    [d setBool:NO       forKey:SCIThemePrefOLEDChat];
    [d setObject:@"off" forKey:SCIThemePrefKeyboard];
}

+ (void)migrateLegacyPrefs {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d boolForKey:SCIThemeMigrationFlag]) return;

    BOOL legacyForceDark = [d boolForKey:@"theme_force_dark"];
    BOOL legacyFullOLED  = [d boolForKey:@"theme_full_oled"];

    // Skip when the user already has a new-format pref (covers reinstalls).
    if (![d stringForKey:SCIThemePrefMode]) {
        if (legacyFullOLED) {
            [d setObject:@"oled" forKey:SCIThemePrefMode];
            [d setBool:YES forKey:SCIThemePrefForce];
        } else if (legacyForceDark) {
            [d setObject:@"dark" forKey:SCIThemePrefMode];
            [d setBool:YES forKey:SCIThemePrefForce];
        } else {
            [d setObject:@"off" forKey:SCIThemePrefMode];
        }
    }
    [d setBool:YES forKey:SCIThemeMigrationFlag];
}

@end
