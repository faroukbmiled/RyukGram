// Full last active — replace "Active Xm/h ago" subtitle with the full date.

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSDateFormatter *sciDMDateFormatter(void) {
    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [NSDateFormatter new];
        df.dateFormat = @"MMM d 'at' h:mm a";
    });
    return df;
}

static NSDate *sciLastActiveDateForTitleView(UIView *titleView) {
    SEL delSel = NSSelectorFromString(@"delegate");
    if (![titleView respondsToSelector:delSel]) return nil;
    id delegate = ((id (*)(id, SEL))objc_msgSend)(titleView, delSel);
    if (!delegate) return nil;
    Ivar spIvar = class_getInstanceVariable([delegate class], "_stateProvider");
    if (!spIvar) return nil;
    id stateProvider = object_getIvar(delegate, spIvar);
    if (!stateProvider) return nil;
    SEL vmSel = NSSelectorFromString(@"viewModel");
    if (![stateProvider respondsToSelector:vmSel]) return nil;
    id viewModel = ((id (*)(id, SEL))objc_msgSend)(stateProvider, vmSel);
    if (!viewModel) return nil;
    @try {
        id v = [viewModel valueForKey:@"lastActiveTime"];
        if ([v isKindOfClass:[NSDate class]]) return v;
        if ([v isKindOfClass:[NSNumber class]]) {
            double t = [v doubleValue];
            if (t > 1e12) t /= 1000.0;
            if (t > 1e6) return [NSDate dateWithTimeIntervalSince1970:t];
        }
    } @catch (NSException *e) {}
    return nil;
}

static void sciRewriteSubtitle(UIView *titleView) {
    if (![SCIUtils getBoolPref:@"dm_full_last_active"]) return;
    SEL csvm = NSSelectorFromString(@"_currentSubtitleViewModel");
    if (![titleView respondsToSelector:csvm]) return;
    id sub = ((id (*)(id, SEL))objc_msgSend)(titleView, csvm);
    if (!sub) return;

    NSDate *date = sciLastActiveDateForTitleView(titleView);
    if (!date) return;

    // Within IG's ~5min presence window — let IG render "Active now".
    if ([[NSDate date] timeIntervalSinceDate:date] < 300) return;

    @try {
        id current = [sub valueForKey:@"text"];
        if (![current isKindOfClass:[NSAttributedString class]]) return;
        NSAttributedString *attr = (NSAttributedString *)current;

        NSString *formatted = [sciDMDateFormatter() stringFromDate:date];
        if (!formatted.length) return;
        NSDictionary *attrs = attr.length > 0 ? [attr attributesAtIndex:0 effectiveRange:NULL] : nil;
        NSAttributedString *replacement = [[NSAttributedString alloc] initWithString:formatted attributes:attrs];

        [sub setValue:replacement forKey:@"text"];

        // Mirror onto the label — IG reads text once before our overwrite lands.
        Ivar lIvar = class_getInstanceVariable([titleView class], "_subtitleLabel");
        if (lIvar) {
            UILabel *label = object_getIvar(titleView, lIvar);
            if ([label isKindOfClass:[UILabel class]]) label.attributedText = replacement;
        }
    } @catch (NSException *e) {}
}

%hook IGDirectLeftAlignedTitleView

- (void)setTitleViewModel:(id)vm {
    %orig;
    sciRewriteSubtitle(self);
}

- (void)animationCoordinatorDidUpdate:(id)coordinator {
    %orig;
    sciRewriteSubtitle(self);
}

- (void)layoutSubviews {
    %orig;
    sciRewriteSubtitle(self);
}

%end
