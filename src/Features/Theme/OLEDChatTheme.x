// Pure-black DM thread background + incoming bubbles.
// IGDirectThreadBackgroundImageView / IGDirectMessageBubbleView in InstagramHeaders.h.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "SCITheme.h"

%group OLEDChatThemeGroup

%hook IGDirectThreadBackgroundImageView
- (void)layoutSubviews {
    %orig;
    if (![SCITheme effectiveDark]) return;
    self.image = nil;
    self.backgroundColor = [SCITheme backgroundColor];
}
- (void)setImage:(UIImage *)image {
    if (![SCITheme effectiveDark]) { %orig; return; }
    %orig(nil);
    self.backgroundColor = [SCITheme backgroundColor];
}
- (void)setBackgroundColor:(UIColor *)color {
    if (![SCITheme effectiveDark]) { %orig; return; }
    %orig([SCITheme backgroundColor]);
}
%end

%hook IGDirectMessageBubbleView
- (void)layoutSubviews {
    %orig;
    if (![SCITheme effectiveDark]) return;
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
