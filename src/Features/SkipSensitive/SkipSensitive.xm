// Skip sensitive-content cover. On IGMediaOverlayCell appearance, find the
// Bloks reveal button by its label and fire its tap gesture — runs IG's own
// reveal flow. Section-controller selectors don't trigger redraw on this IG
// version (reveal is Bloks-driven).

#import <UIKit/UIKit.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>
#import <objc/message.h>

static inline BOOL sci_skipSensitiveOn(void) {
    return [SCIUtils getBoolPref:@"skip_sensitive_content"];
}

%hook IGMedia
- (id)mediaOverlay {
    if (sci_skipSensitiveOn()) return nil;
    return %orig;
}
%end

#pragma mark - Bloks reveal-button tap

static NSArray<NSString *> *sci_revealNeedles(void) {
    return @[@"see reel", @"see post", @"see photo", @"see video",
             @"show post", @"show video", @"show photo"];
}

static NSString *sci_viewText(UIView *v) {
    NSString *txt = nil;
    @try {
        if ([v respondsToSelector:@selector(text)]) {
            id t = [v performSelector:@selector(text)];
            if ([t isKindOfClass:[NSString class]]) txt = t;
        }
        if (!txt && [v respondsToSelector:@selector(attributedText)]) {
            id at = [v performSelector:@selector(attributedText)];
            if ([at isKindOfClass:[NSAttributedString class]]) txt = [at string];
        }
    } @catch (__unused id e) {}
    return txt;
}

static BOOL sci_subtreeMatches(UIView *v, NSArray<NSString *> *needles) {
    NSString *t = sci_viewText(v);
    if (t.length) {
        for (NSString *n in needles) {
            if ([t rangeOfString:n options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
        }
    }
    for (UIView *s in v.subviews) {
        if (sci_subtreeMatches(s, needles)) return YES;
    }
    return NO;
}

static UIView *sci_findRevealButton(UIView *root) {
    NSString *cls = NSStringFromClass([root class]);
    if ([cls isEqualToString:@"BKBloksFlexboxView"] && root.gestureRecognizers.count > 0) {
        for (UIGestureRecognizer *g in root.gestureRecognizers) {
            if ([g isKindOfClass:[UITapGestureRecognizer class]] &&
                sci_subtreeMatches(root, sci_revealNeedles())) {
                return root;
            }
        }
    }
    for (UIView *sub in root.subviews) {
        UIView *r = sci_findRevealButton(sub);
        if (r) return r;
    }
    return nil;
}

static void sci_fireTap(UIView *bloksView) {
    UITapGestureRecognizer *tap = nil;
    for (UIGestureRecognizer *g in bloksView.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) { tap = (UITapGestureRecognizer *)g; break; }
    }
    if (!tap) return;
    @try {
        ((void(*)(id, SEL, NSInteger))objc_msgSend)(tap, @selector(setState:), UIGestureRecognizerStateBegan);
        ((void(*)(id, SEL, NSInteger))objc_msgSend)(tap, @selector(setState:), UIGestureRecognizerStateEnded);
    } @catch (__unused id e) {}
    SEL handler = NSSelectorFromString(@"_handleGestureRecognizer:");
    if ([bloksView respondsToSelector:handler]) {
        ((void(*)(id, SEL, id))objc_msgSend)(bloksView, handler, tap);
    }
}

%hook IGMediaOverlayCell
- (void)didMoveToWindow {
    %orig;
    if (!sci_skipSensitiveOn() || !self.window) return;
    UIView *cell = (UIView *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *btn = sci_findRevealButton(cell);
        if (btn) sci_fireTap(btn);
    });
}
%end
