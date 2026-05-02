#import "../../Utils.h"

%hook IGDirectThreadViewBottomSwipeFeatureController
- (void)setupBottomSwipeableScrollManagerIfNecessary {
    if ([SCIUtils getBoolPref:@"disable_disappearing_mode_swipe"]) return;
    %orig;
}
%end

%hook IGDirectDisappearingModeSwipeHandler
- (void)handleBottomSwipeableScrollUpdate {
    if ([SCIUtils getBoolPref:@"disable_disappearing_mode_swipe"]) return;
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"])
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm vanish mode")];
    else %orig;
}
- (id)getSwipeableScrollHintTextInfo {
    if ([SCIUtils getBoolPref:@"disable_disappearing_mode_swipe"]) return nil;
    return %orig;
}
%end

%hook IGDirectThreadViewController
- (void)messageListViewControllerDidToggleShhMode:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"])
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm vanish mode")];
    else %orig;
}

- (void)messageListViewControllerDidReplayInShhMode:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"])
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm vanish mode")];
    else %orig;
}
%end
