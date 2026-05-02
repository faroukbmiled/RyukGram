#import "../../Utils.h"

%hook IGCommentComposer.IGCommentComposerController
- (void)onSendButtonTap {
    if ([SCIUtils getBoolPref:@"post_comment_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm posting comment")];
    } else {
        return %orig;
    }
}
%end