#import "../../Utils.h"
#import "../../InstagramHeaders.h"

%hook IGMainStoryTrayDataSource
- (BOOL)isEmpty {
    if ([SCIUtils getBoolPref:@"hide_stories_tray"]) return YES;
    return %orig;
}
%end
