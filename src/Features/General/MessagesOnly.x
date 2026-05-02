// Messages-only mode — no-op the tab creators we don't want, force inbox at launch.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../SCIChrome.h"
#import <objc/runtime.h>
#import <objc/message.h>

static BOOL sciMsgOnly(void) { return [SCIUtils getBoolPref:@"messages_only"]; }
static BOOL sciMsgOnlyHideTabBar(void) {
    return sciMsgOnly() && [SCIUtils getBoolPref:@"messages_only_hide_tabbar"];
}

%hook IGTabBarController

// Block tab creation entirely so they never enter the buttons array (no gaps).
- (void)_createAndConfigureTimelineButtonIfNeeded   { if (sciMsgOnly()) return; %orig; }
- (void)_createAndConfigureReelsButtonIfNeeded      { if (sciMsgOnly()) return; %orig; }
- (void)_createAndConfigureExploreButtonIfNeeded    { if (sciMsgOnly()) return; %orig; }
- (void)_createAndConfigureCameraButtonIfNeeded     { if (sciMsgOnly()) return; %orig; }
- (void)_createAndConfigureDynamicTabButtonIfNeeded { if (sciMsgOnly()) return; %orig; }
- (void)_createAndConfigureNewsButtonIfNeeded       { if (sciMsgOnly()) return; %orig; }
- (void)_createAndConfigureStreamsButtonIfNeeded    { if (sciMsgOnly()) return; %orig; }

// Force initial selection to inbox once after the tab bar has fully laid out.
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static BOOL launched = NO;
    if (sciMsgOnly() && !launched) {
        launched = YES;
        SEL s = NSSelectorFromString(@"_directInboxButtonPressed");
        if ([self respondsToSelector:s])
            ((void(*)(id, SEL))objc_msgSend)(self, s);
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (!sciMsgOnlyHideTabBar()) return;
    Ivar tbIv = class_getInstanceVariable([self class], "_tabBar");
    UIView *tabBar = tbIv ? object_getIvar(self, tbIv) : nil;
    if (tabBar) {
        tabBar.hidden = YES;
        tabBar.alpha = 0.0;
    }
    UIViewController *selected = [self valueForKey:@"selectedViewController"];
    if (selected.isViewLoaded) {
        selected.view.frame = self.view.bounds;
    }
}

// Surface enum no longer maps cleanly to the trimmed _buttons array, so flip
// the selected state ourselves and nudge the liquid-glass indicator.
%new - (void)sciSyncTabBarSelection:(NSString *)which {
    Class c = [self class];
    Ivar ibIv = class_getInstanceVariable(c, "_directInboxButton");
    Ivar pbIv = class_getInstanceVariable(c, "_profileButton");
    UIButton *inbox = ibIv ? object_getIvar(self, ibIv) : nil;
    UIButton *profile = pbIv ? object_getIvar(self, pbIv) : nil;
    BOOL profileActive = [which isEqualToString:@"profile"];
    if ([inbox respondsToSelector:@selector(setSelected:)]) inbox.selected = !profileActive;
    if ([profile respondsToSelector:@selector(setSelected:)]) profile.selected = profileActive;

    // No-op on classic tab bar (selector only exists on IGLiquidGlassInteractiveTabBar).
    Ivar tbIv = class_getInstanceVariable(c, "_tabBar");
    id tabBar = tbIv ? object_getIvar(self, tbIv) : nil;
    NSInteger idx = profileActive ? 1 : 0;
    SEL setIdx = NSSelectorFromString(@"setSelectedTabBarItemIndex:animateIndicator:");
    if ([tabBar respondsToSelector:setIdx])
        ((void(*)(id, SEL, NSInteger, BOOL))objc_msgSend)(tabBar, setIdx, idx, YES);
}

- (void)_directInboxButtonPressed {
    %orig;
    if (sciMsgOnly())
        ((void(*)(id, SEL, id))objc_msgSend)(self, @selector(sciSyncTabBarSelection:), @"inbox");
}
- (void)_profileButtonPressed {
    %orig;
    if (sciMsgOnly())
        ((void(*)(id, SEL, id))objc_msgSend)(self, @selector(sciSyncTabBarSelection:), @"profile");
}

%end

// Floating settings gear is parented to IG's nav header so it inherits the header's
// blur, z-order, and scroll-collapse animation.
static const void *kSCIMsgOnlyBtnKey = &kSCIMsgOnlyBtnKey;

static UIView *sciFindInboxHeaderView(UIView *root) {
    if (!root) return nil;
    if ([NSStringFromClass([root class]) containsString:@"NavigationHeaderView"]) return root;
    for (UIView *sub in root.subviews) {
        UIView *r = sciFindInboxHeaderView(sub);
        if (r) return r;
    }
    return nil;
}

%hook IGDirectInboxViewController

- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *vc = (UIViewController *)self;
    if (!sciMsgOnlyHideTabBar() || !vc.isViewLoaded) return;

    UIView *header = sciFindInboxHeaderView(vc.view);
    if (!header) return;

    SCIChromeButton *btn = objc_getAssociatedObject(header, kSCIMsgOnlyBtnKey);
    if (!btn || btn.superview != header) {
        btn = [[SCIChromeButton alloc] initWithSymbol:@"gearshape"
                                            pointSize:18
                                             diameter:32];
        btn.iconTint = [UIColor labelColor];
        btn.bubbleColor = [UIColor clearColor];
        btn.translatesAutoresizingMaskIntoConstraints = YES;
        [btn addTarget:self action:@selector(sciMsgOnlyOpenSettings)
              forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:btn];
        objc_setAssociatedObject(header, kSCIMsgOnlyBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // IG buries its trailing buttons inside a zero-frame wrapper UIView; recurse
    // to find the rightmost UIButton, then mirror its Y + effective alpha so we
    // collapse with the rest of IG's chrome on scroll.
    UIView *anchor = nil;
    CGRect anchorInHeader = CGRectZero;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:header];
    while (stack.count) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if (v != header && v != btn
            && [v isKindOfClass:[UIButton class]]
            && !CGRectIsEmpty(v.bounds)) {
            CGRect r = [v convertRect:v.bounds toView:header];
            if (CGRectGetMinX(r) > header.bounds.size.width * 0.6
                && (!anchor || CGRectGetMidX(r) > CGRectGetMidX(anchorInHeader))) {
                anchor = v;
                anchorInHeader = r;
            }
        }
        for (UIView *s in v.subviews) [stack addObject:s];
    }

    CGFloat side = 32;
    CGFloat y = anchor ? CGRectGetMidY(anchorInHeader) - side * 0.5
                       : (header.bounds.size.height - side) * 0.5;
    btn.frame = CGRectMake(12, y, side, side);

    if (anchor) {
        CGFloat eff = 1.0;
        BOOL hidden = NO;
        for (UIView *v = anchor; v && v != header; v = v.superview) {
            if (v.hidden) hidden = YES;
            eff *= v.alpha;
        }
        btn.alpha = eff;
        btn.hidden = hidden;
    } else {
        btn.alpha = 1.0;
        btn.hidden = NO;
    }
    [header bringSubviewToFront:btn];
}

%new - (void)sciMsgOnlyOpenSettings {
    UIViewController *vc = (UIViewController *)self;
    [SCIUtils showSettingsVC:vc.view.window];
}

%end
