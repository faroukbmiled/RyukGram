// Confirmation dialog before pull-to-refresh wipes preserved unsent
// messages. Gated by keep_deleted_message + warn_refresh_clears_preserved.
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

extern NSMutableSet *sciGetPreservedIds(void);
extern void sciClearPreservedIds(void);

static BOOL sciRefreshConfirmInFlight = NO;
static BOOL sciRefreshAlertVisible = NO;

static UIRefreshControl *sciFindRefreshControl(UIViewController *vc) {
    Class igRC = NSClassFromString(@"IGRefreshControl");
    NSMutableArray *stack = [NSMutableArray arrayWithObject:vc.view];
    while (stack.count > 0) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if ((igRC && [v isKindOfClass:igRC]) || [v isKindOfClass:[UIRefreshControl class]]) {
            return (UIRefreshControl *)v;
        }
        for (UIView *sub in v.subviews) [stack addObject:sub];
    }
    return nil;
}

// Cancel path resets the refresh control's state and animates the scroll
// view's contentInset back to its idle value (IG leaves it expanded otherwise).
static void sciCancelRefresh(UIViewController *vc) {
    UIRefreshControl *rc = sciFindRefreshControl(vc);
    if (!rc) return;

    Ivar stateIvar = class_getInstanceVariable([rc class], "_refreshState");
    if (stateIvar) {
        ptrdiff_t off = ivar_getOffset(stateIvar);
        *(NSInteger *)((char *)(__bridge void *)rc + off) = 0;
    }
    Ivar animIvar = class_getInstanceVariable([rc class], "_swiftAnimationInfo");
    if (animIvar) object_setIvar(rc, animIvar, nil);
    if ([rc respondsToSelector:@selector(endRefreshing)]) [rc endRefreshing];

    SEL didEnd = NSSelectorFromString(@"refreshControlDidEndFinishLoadingAnimation:");
    if ([vc respondsToSelector:didEnd]) {
        ((void(*)(id, SEL, id))objc_msgSend)(vc, didEnd, rc);
    }

    UIScrollView *scroll = nil;
    UIView *cur = rc.superview;
    while (cur) {
        if ([cur isKindOfClass:[UIScrollView class]]) { scroll = (UIScrollView *)cur; break; }
        cur = cur.superview;
    }
    if (scroll) {
        SEL idleSel = NSSelectorFromString(@"idleTopContentInsetForRefreshControl:");
        CGFloat idleInset = scroll.contentInset.top;
        if ([vc respondsToSelector:idleSel]) {
            idleInset = ((CGFloat(*)(id, SEL, id))objc_msgSend)(vc, idleSel, rc);
        }
        UIEdgeInsets insets = scroll.contentInset;
        insets.top = idleInset;
        [UIView animateWithDuration:0.25 animations:^{
            scroll.contentInset = insets;
            CGPoint o = scroll.contentOffset;
            if (o.y < -idleInset) o.y = -idleInset;
            scroll.contentOffset = o;
        }];
    }
}

static void (*orig_pullToRefresh)(id self, SEL _cmd);
static void new_pullToRefresh(id self, SEL _cmd) {
    if (sciRefreshConfirmInFlight ||
        ![SCIUtils getBoolPref:@"keep_deleted_message"] ||
        ![SCIUtils getBoolPref:@"warn_refresh_clears_preserved"]) {
        orig_pullToRefresh(self, _cmd);
        return;
    }

    // Drop re-entrant calls — IG fires this repeatedly during the gesture.
    if (sciRefreshAlertVisible) return;

    NSUInteger count = sciGetPreservedIds().count;
    if (count == 0) {
        orig_pullToRefresh(self, _cmd);
        return;
    }

    UIViewController *vc = (UIViewController *)self;
    NSString *fmt = (count == 1)
        ? SCILocalized(@"Refreshing the DMs tab will clear %lu preserved unsent message. This cannot be undone.")
        : SCILocalized(@"Refreshing the DMs tab will clear %lu preserved unsent messages. This cannot be undone.");
    NSString *msg = [NSString stringWithFormat:fmt, (unsigned long)count];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:SCILocalized(@"Clear preserved messages?")
                                                                  message:msg
                                                           preferredStyle:UIAlertControllerStyleAlert];

    __weak UIViewController *weakSelf = vc;
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Cancel") style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *a) {
        sciCancelRefresh(weakSelf);
        sciRefreshAlertVisible = NO;
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Refresh") style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        sciRefreshAlertVisible = NO;
        id strongSelf = weakSelf;
        if (!strongSelf) return;
        sciClearPreservedIds();
        sciRefreshConfirmInFlight = YES;
        ((void(*)(id, SEL))objc_msgSend)(strongSelf, _cmd);
        sciRefreshConfirmInFlight = NO;
    }]];

    sciRefreshAlertVisible = YES;
    UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:alert animated:YES completion:nil];
}

%ctor {
    Class cls = NSClassFromString(@"IGDirectInboxViewController");
    if (!cls) return;
    SEL sel = NSSelectorFromString(@"_pullToRefreshIfPossible");
    if (class_getInstanceMethod(cls, sel))
        MSHookMessageEx(cls, sel, (IMP)new_pullToRefresh, (IMP *)&orig_pullToRefresh);
}
