// Long-press the DM tab-bar button → open the RyukGram gallery. Coexists with
// messages-only mode (which owns the tap).

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Gallery/SCIGalleryViewController.h"
#import <objc/runtime.h>

static const void *kSCIDMLongPressKey = &kSCIDMLongPressKey;

static BOOL sciDMLongPressEnabled(void) {
    return [SCIUtils getBoolPref:@"dm_tab_long_press_gallery"];
}

%hook IGTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    Ivar iv = class_getInstanceVariable([self class], "_directInboxButton");
    UIView *btn = iv ? object_getIvar(self, iv) : nil;
    if (!btn) return;
    if (objc_getAssociatedObject(btn, kSCIDMLongPressKey)) return;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(sciDMTabLongPressOpenGallery:)];
    lp.minimumPressDuration = 0.5;
    lp.cancelsTouchesInView = YES;
    lp.delegate = (id<UIGestureRecognizerDelegate>)self;
    [btn addGestureRecognizer:lp];
    objc_setAssociatedObject(btn, kSCIDMLongPressKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Block recognition when pref off so IG's tap runs untouched.
%new - (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    if ([g isKindOfClass:[UILongPressGestureRecognizer class]] && g.view) {
        UIGestureRecognizer *ours = objc_getAssociatedObject(g.view, kSCIDMLongPressKey);
        if (ours == g) return sciDMLongPressEnabled();
    }
    return YES;
}

%new - (void)sciDMTabLongPressOpenGallery:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [SCIGalleryViewController presentGallery];
}

%end
