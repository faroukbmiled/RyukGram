#import "../../Utils.h"

%hook IGPendingRequestView
- (void)_onApproveButtonTapped {
    if ([SCIUtils getBoolPref:@"follow_request_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm follow requests")];
    } else {
        return %orig;
    }
}
- (void)_onIgnoreButtonTapped {
    if ([SCIUtils getBoolPref:@"follow_request_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm follow requests")];
    } else {
        return %orig;
    }
}
%end
