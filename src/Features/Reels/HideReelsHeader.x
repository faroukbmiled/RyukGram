#import "../../Utils.h"

%hook IGSundialViewerNavigationBarOld
- (void)didMoveToWindow {
    %orig;

    if ([SCIUtils getBoolPref:@"hide_reels_header"]) {

        [self removeFromSuperview];
    }
}
%end
