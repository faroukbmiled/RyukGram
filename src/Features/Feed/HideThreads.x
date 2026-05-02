#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// Remove suggested threads posts (carousel, under suggested posts in feed)
%hook BKBloksViewHelper
- (id)initWithObjectSet:(id)arg1 bloksData:(id)arg2 delegate:(id)arg3 {
    if ([SCIUtils getBoolPref:@"no_suggested_threads"]) {
        return nil;
    }
    
    return %orig;
}
%end