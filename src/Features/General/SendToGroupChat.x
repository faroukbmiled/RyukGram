// Hide / confirm the "Send to group chat" facepile shown under "Send separately"
// in the share sheet. Classes declared in InstagramHeaders.h.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>

static const void *kSCISTGTapKey = &kSCISTGTapKey;

static BOOL sciSTGIsFacepileClass(UIView *v) {
    return [NSStringFromClass([v class]) containsString:@"CreateOrSendToGroupFacepileButton"];
}

static UIView *sciSTGFindInner(UIView *outer) {
    UIView *inner = nil;
    @try { inner = [outer valueForKey:@"bottomButtonsView"]; } @catch (__unused id e) {}
    if (!inner) {
        for (UIView *sub in outer.subviews) {
            if ([NSStringFromClass([sub class]) containsString:@"IGSharesheetBottomButtonsView"]) {
                return sub;
            }
        }
    }
    return inner;
}

// Shrink the bottom-buttons container to fit only its non-facepile children
// plus a small bottom margin. Never grows the size.
static CGSize sciSTGShrunkSize(UIView *outer, CGSize fallback) {
    UIView *inner = sciSTGFindInner(outer);
    if (!inner) return fallback;
    CGFloat maxY = 0;
    for (UIView *sub in inner.subviews) {
        if (sciSTGIsFacepileClass(sub)) continue;
        if (sub.hidden || CGRectIsEmpty(sub.frame)) continue;
        maxY = fmax(maxY, CGRectGetMaxY(sub.frame));
    }
    if (maxY > 0 && maxY + 16 < fallback.height) {
        return CGSizeMake(fallback.width, maxY + 16);
    }
    return fallback;
}

%hook _TtC12IGShareSheet38IGShareSheetBottomButtonsViewContainer

- (CGSize)intrinsicContentSize {
    CGSize r = %orig;
    if (![SCIUtils getBoolPref:@"hide_send_to_group"]) return r;
    CGSize s = sciSTGShrunkSize(self, r);
    if (!CGSizeEqualToSize(s, r)) [self invalidateIntrinsicContentSize];
    return s;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize r = %orig;
    if (![SCIUtils getBoolPref:@"hide_send_to_group"]) return r;
    return sciSTGShrunkSize(self, r);
}

%end

%hook _TtC12IGShareSheet45IGShareSheetCreateOrSendToGroupFacepileButton

- (CGSize)sizeThatFits:(CGSize)size {
    if ([SCIUtils getBoolPref:@"hide_send_to_group"]) return CGSizeZero;
    return %orig;
}

- (CGSize)intrinsicContentSize {
    if ([SCIUtils getBoolPref:@"hide_send_to_group"]) return CGSizeZero;
    return %orig;
}

- (void)didMoveToSuperview {
    %orig;
    if (![SCIUtils getBoolPref:@"hide_send_to_group"] || !self.superview) return;
    self.hidden = YES;
    for (UIView *p = self; p; p = p.superview) {
        [p invalidateIntrinsicContentSize];
        [p setNeedsLayout];
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    if ([SCIUtils getBoolPref:@"hide_send_to_group"]) {
        self.hidden = YES;
        return;
    }
    if (![SCIUtils getBoolPref:@"confirm_send_to_group"]) return;
    if (objc_getAssociatedObject(self, kSCISTGTapKey)) return;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(sciSTGHandleTap:)];
    tap.cancelsTouchesInView = YES;
    [self addGestureRecognizer:tap];
    objc_setAssociatedObject(self, kSCISTGTapKey, tap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// FacepileButton inherits from UIControl with secondaryButtonTappedWithButton:
// registered for TouchUpInside. Replay it after confirmation.
%new - (void)sciSTGHandleTap:(UITapGestureRecognizer *)g {
    [SCIUtils showConfirmation:^{
        if ([self isKindOfClass:[UIControl class]]) {
            [(UIControl *)self sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
    } title:SCILocalized(@"Send to group chat?")];
}

%end
