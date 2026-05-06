// Keyboard appearance override (theme_keyboard: off / dark / oled). Hooks
// install at launch when mode != off; per-call gate via keyboardShouldApply*
// follows system dark/light unless theme_force is on.

#import "../../Utils.h"
#import "SCITheme.h"

%group KeyboardThemeDarkGroup

%hook UITextField
- (BOOL)becomeFirstResponder {
    if ([SCITheme keyboardShouldApplyDark]) self.keyboardAppearance = UIKeyboardAppearanceDark;
    return %orig;
}
%end

%hook UITextView
- (BOOL)becomeFirstResponder {
    if ([SCITheme keyboardShouldApplyDark]) self.keyboardAppearance = UIKeyboardAppearanceDark;
    return %orig;
}
%end

%hook UISearchBar
- (BOOL)becomeFirstResponder {
    if ([SCITheme keyboardShouldApplyDark]) self.keyboardAppearance = UIKeyboardAppearanceDark;
    return %orig;
}
%end

%end

%group KeyboardThemeOLEDGroup

%hook UIKBBackdropView
- (void)layoutSubviews {
    %orig;
    if (![SCITheme keyboardShouldApplyOLED]) return;
    self.backgroundColor = [UIColor blackColor];
    for (UIView *sub in self.subviews) sub.backgroundColor = [UIColor blackColor];
}
- (void)setBackgroundColor:(UIColor *)color {
    if (![SCITheme keyboardShouldApplyOLED]) { %orig; return; }
    if (![color isEqual:[UIColor blackColor]]) {
        %orig([UIColor blackColor]);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    if (![SCITheme keyboardShouldApplyOLED]) return;
    self.backgroundColor = [UIColor blackColor];
    for (UIView *sub in self.subviews) sub.backgroundColor = [UIColor blackColor];
}
%end

%hook UIKBKeyplaneChargedView
- (void)layoutSubviews {
    %orig;
    if (![SCITheme keyboardShouldApplyOLED]) return;
    self.backgroundColor = [UIColor blackColor];
}
%end

%end

%ctor {
    [SCITheme migrateLegacyPrefs];
    NSString *raw = [[NSUserDefaults standardUserDefaults] stringForKey:SCIThemePrefKeyboard];
    NSString *mode = raw.length ? raw : @"off";
    if ([mode isEqualToString:@"off"]) return;

    %init(KeyboardThemeDarkGroup);
    if ([mode isEqualToString:@"oled"]) {
        %init(KeyboardThemeOLEDGroup);
    }
}
