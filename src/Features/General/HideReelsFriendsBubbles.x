// Reels: hide the friends-tab avatar bubbles and the floating social-context
// overlay (reposted / commented / etc).

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>

// MARK: - Friends-tab avatar bubbles

// Cached ancestor check so the sizing hooks below don't re-walk per call.
static const void *kSCIFRBScopedKey = &kSCIFRBScopedKey;

static BOOL sciFRBIsReelsFacepile(UIView *v) {
    NSNumber *cached = objc_getAssociatedObject(v, kSCIFRBScopedKey);
    if (cached) return cached.boolValue;
    Class tabCls = NSClassFromString(
        @"_TtC32IGSundialFriendsLaneEntryPointUI30IGFriendsLaneEntryPointTabView");
    BOOL ok = NO;
    for (UIView *p = v; p; p = p.superview) {
        if (tabCls && [p isKindOfClass:tabCls]) { ok = YES; break; }
    }
    if (v.window) {
        objc_setAssociatedObject(v, kSCIFRBScopedKey, @(ok), OBJC_ASSOCIATION_RETAIN);
    }
    return ok;
}

%hook IGStoryFacepileView

- (void)setFrame:(CGRect)frame {
    if ([SCIUtils getBoolPref:@"hide_reels_friends_bubbles"] && sciFRBIsReelsFacepile(self)) {
        frame.size = CGSizeZero;
    }
    %orig(frame);
}

- (void)setBounds:(CGRect)bounds {
    if ([SCIUtils getBoolPref:@"hide_reels_friends_bubbles"] && sciFRBIsReelsFacepile(self)) {
        bounds.size = CGSizeZero;
    }
    %orig(bounds);
}

- (CGSize)sizeThatFits:(CGSize)size {
    if ([SCIUtils getBoolPref:@"hide_reels_friends_bubbles"] && sciFRBIsReelsFacepile(self)) {
        return CGSizeZero;
    }
    return %orig;
}

- (CGSize)intrinsicContentSize {
    if ([SCIUtils getBoolPref:@"hide_reels_friends_bubbles"] && sciFRBIsReelsFacepile(self)) {
        return CGSizeZero;
    }
    return %orig;
}

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    if ([SCIUtils getBoolPref:@"hide_reels_friends_bubbles"] && sciFRBIsReelsFacepile(self)) {
        self.hidden = YES;
    }
}

%end

// MARK: - Floating social context overlay

%hook _TtC25IGFloatingSocialContextUI39IGFloatingSocialContextMediaOverlayView

- (void)setHidden:(BOOL)hidden {
    if ([SCIUtils getBoolPref:@"hide_reels_floating_social_context"]) {
        %orig(YES);
    } else {
        %orig(hidden);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (self.window && [SCIUtils getBoolPref:@"hide_reels_floating_social_context"]) {
        self.hidden = YES;
    }
}

%end
