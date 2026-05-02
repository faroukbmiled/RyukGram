#import "../../InstagramHeaders.h"
#import "../../Utils.h"

%hook IGDirectThreadThemePickerViewController
- (void)themeNewPickerSectionController:(id)arg1 didSelectTheme:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm changing theme")];
    } else {
        return %orig;
    }
}
- (void)themePickerSectionController:(id)arg1 didSelectThemeId:(id)arg2 {
    if ([SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm changing theme")];
    } else {
        return %orig;
    }
}
%end

%hook IGDirectThreadThemeKitSwift.IGDirectThreadThemePreviewController
- (void)primaryButtonTapped {
    if ([SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm changing theme")];
    } else {
        return %orig;
    }
}
%end
