// Keyboard appearance override (theme_keyboard: off / dark / oled).
//
// Search-keyboard reset fix: UIKBBackdropView reverts to translucent on
// context change (focus moves into a UISearchBar, etc.). Hooking
// setBackgroundColor: + didMoveToWindow snaps any future repaint back to black.

#import "../../Utils.h"
#import "SCITheme.h"

static inline NSString *sciKeyboardMode(void) {
    NSString *raw = [[NSUserDefaults standardUserDefaults] stringForKey:SCIThemePrefKeyboard];
    return raw.length ? raw : @"off";
}

%group KeyboardThemeDarkGroup

%hook UITextField
- (BOOL)becomeFirstResponder {
    self.keyboardAppearance = UIKeyboardAppearanceDark;
    return %orig;
}
%end

%hook UITextView
- (BOOL)becomeFirstResponder {
    self.keyboardAppearance = UIKeyboardAppearanceDark;
    return %orig;
}
%end

%hook UISearchBar
- (BOOL)becomeFirstResponder {
    self.keyboardAppearance = UIKeyboardAppearanceDark;
    return %orig;
}
%end

%end

%group KeyboardThemeOLEDGroup

%hook UIKBBackdropView
- (void)layoutSubviews {
    %orig;
    self.backgroundColor = [UIColor blackColor];
    for (UIView *sub in self.subviews) sub.backgroundColor = [UIColor blackColor];
}
- (void)setBackgroundColor:(UIColor *)color {
    if (![color isEqual:[UIColor blackColor]]) {
        %orig([UIColor blackColor]);
        return;
    }
    %orig;
}
- (void)didMoveToWindow {
    %orig;
    self.backgroundColor = [UIColor blackColor];
    for (UIView *sub in self.subviews) sub.backgroundColor = [UIColor blackColor];
}
%end

%hook UIKBKeyplaneChargedView
- (void)layoutSubviews {
    %orig;
    self.backgroundColor = [UIColor blackColor];
}
%end

%end

%ctor {
    [SCITheme migrateLegacyPrefs];
    NSString *mode = sciKeyboardMode();
    if ([mode isEqualToString:@"off"]) return;
    if (![SCITheme forceTheme] && ![SCITheme isSystemDark]) return;

    %init(KeyboardThemeDarkGroup);

    if ([mode isEqualToString:@"oled"]) {
        %init(KeyboardThemeOLEDGroup);
    }
}
