// Forces IG into the chosen appearance when `theme_force` is on.

#import "../../Utils.h"
#import "SCITheme.h"

%group ForceAppearanceGroup

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    self.overrideUserInterfaceStyle = [SCITheme overrideStyle];
}
- (void)becomeKeyWindow {
    %orig;
    self.overrideUserInterfaceStyle = [SCITheme overrideStyle];
}
%end

%end

%ctor {
    [SCITheme migrateLegacyPrefs];
    if ([SCITheme shouldOverrideAppearance]) {
        %init(ForceAppearanceGroup);
    }
}
