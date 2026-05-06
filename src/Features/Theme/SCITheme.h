// Single source of truth for the theme stack — read by every theme hook so
// the mode/force matrix lives in one place.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIThemeMode) {
    SCIThemeModeOff = 0,
    SCIThemeModeLight,
    SCIThemeModeDark,
    SCIThemeModeOLED,
};

extern NSString *const SCIThemePrefMode;     // string: off/light/dark/oled
extern NSString *const SCIThemePrefForce;    // bool
extern NSString *const SCIThemePrefOLEDChat; // bool
extern NSString *const SCIThemePrefKeyboard; // string: off/dark/oled

@interface SCITheme : NSObject

+ (SCIThemeMode)mode;
+ (BOOL)forceTheme;

+ (NSString *)modeKey;
+ (SCIThemeMode)modeForKey:(NSString *)key;

// `effectiveDark` answers "is IG currently in a dark appearance?" — trusts
// the system trait collection unless force is on.
+ (BOOL)isSystemDark;
+ (BOOL)effectiveDark;

+ (BOOL)shouldOverrideAppearance;
+ (UIUserInterfaceStyle)overrideStyle;
+ (BOOL)shouldRecolor;

// Keyboard theme resolved against current state: returns NO when
// `theme_keyboard` is off, YES when force is on, else mirrors system dark.
+ (BOOL)keyboardShouldApplyDark;
+ (BOOL)keyboardShouldApplyOLED;

+ (UIColor *)backgroundColor;
+ (UIColor *)surfaceColor;

+ (BOOL)colorIsNearBlack:(nullable UIColor *)color;

// Hex helpers (#RRGGBB / #RRGGBBAA).
+ (nullable UIColor *)colorFromHex:(nullable NSString *)hex;
+ (NSString *)hexFromColor:(UIColor *)color;

// Folds the legacy `theme_force_dark` / `theme_full_oled` prefs onto the new
// keys. Idempotent.
+ (void)migrateLegacyPrefs;

+ (void)resetToDefaults;

@end

NS_ASSUME_NONNULL_END
