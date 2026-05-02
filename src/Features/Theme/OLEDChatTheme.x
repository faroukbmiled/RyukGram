// Pure-black DM thread background + incoming bubbles.
// IGDirectThreadBackgroundImageView / IGDirectMessageBubbleView in InstagramHeaders.h.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "SCITheme.h"

%group OLEDChatThemeGroup

%hook IGDirectThreadBackgroundImageView
- (void)layoutSubviews {
    %orig;
    self.image = nil;
    self.backgroundColor = [SCITheme backgroundColor];
}
- (void)setImage:(UIImage *)image {
    %orig(nil);
    self.backgroundColor = [SCITheme backgroundColor];
}
- (void)setBackgroundColor:(UIColor *)color {
    %orig([SCITheme backgroundColor]);
}
%end

%hook IGDirectMessageBubbleView
- (void)layoutSubviews {
    %orig;
    // Only swap the incoming-bubble surface — leaves tinted outgoing bubbles alone.
    if ([SCITheme colorIsNearBlack:self.backgroundColor]) {
        self.backgroundColor = [SCITheme backgroundColor];
    }
}
%end

%end

%ctor {
    [SCITheme migrateLegacyPrefs];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCIThemePrefOLEDChat]) {
        %init(OLEDChatThemeGroup);
    }
}
