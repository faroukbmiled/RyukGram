#import "SCIMediaChrome.h"
#import "SCIAssetUtils.h"
#import "../Utils.h"

CGFloat const SCIMediaChromeTopBarContentHeight = 44.0;
CGFloat const SCIMediaChromeBottomBarHeight = 52.0;

static CGFloat const kSCIMediaChromeTopIconPointSize = 17.0;
static CGFloat const kSCIMediaChromeBottomIconPointSize = 17.0;
static CGFloat const kSCIMediaChromeFloatingCornerRadius = 26.0;
static CGFloat const kSCIMediaChromeHorizontalMargin = 16.0;
static CGFloat const kSCIMediaChromeBottomGap = 12.0;

UIBlurEffect *SCIMediaChromeBlurEffect(void) {
    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent];
}

void SCIApplyMediaChromeNavigationBar(UINavigationBar *bar) {
    if (!bar) return;
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundEffect = SCIMediaChromeBlurEffect();
        appearance.shadowColor = [UIColor clearColor];
        appearance.shadowImage = [UIImage new];
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
        bar.compactAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            bar.compactScrollEdgeAppearance = appearance;
        }
    }
    bar.tintColor = [UIColor labelColor];
}

UILabel *SCIMediaChromeTitleLabel(NSString *text) {
    UILabel *label = [[UILabel alloc] init];
    label.text = text ?: @"";
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    label.textColor = [UIColor labelColor];
    label.textAlignment = NSTextAlignmentCenter;
    [label sizeToFit];
    return label;
}

UIImage *SCIMediaChromeTopIcon(NSString *resourceName) {
    return [SCIAssetUtils instagramIconNamed:(resourceName.length > 0 ? resourceName : @"more")
                                   pointSize:kSCIMediaChromeTopIconPointSize];
}

UIImage *SCIMediaChromeBottomIcon(NSString *resourceName) {
    return [SCIAssetUtils instagramIconNamed:(resourceName.length > 0 ? resourceName : @"more")
                                   pointSize:kSCIMediaChromeBottomIconPointSize];
}

UIBarButtonItem *SCIMediaChromeTopBarButtonItem(NSString *resourceName, id target, SEL action) {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:SCIMediaChromeTopIcon(resourceName)
                                                              style:UIBarButtonItemStylePlain
                                                             target:target
                                                             action:action];
    item.tintColor = [UIColor labelColor];
    return item;
}

// Floating capsule that drifts above the safe-area bottom inset. Uses an
// ultra-thin material with a hairline border + soft drop shadow — visually
// distinct from upstream's edge-to-edge blurred bar.
UIView *SCIMediaChromeInstallBottomBar(UIView *hostView) {
    UIView *bar = [[UIView alloc] initWithFrame:CGRectZero];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.clipsToBounds = NO;
    bar.layer.shadowColor = [UIColor blackColor].CGColor;
    bar.layer.shadowOpacity = 0.18;
    bar.layer.shadowRadius = 14.0;
    bar.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [hostView addSubview:bar];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:SCIMediaChromeBlurEffect()];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    blur.clipsToBounds = YES;
    blur.layer.cornerRadius = kSCIMediaChromeFloatingCornerRadius;
    blur.layer.cornerCurve = kCACornerCurveContinuous;
    blur.layer.borderWidth = 0.5;
    blur.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    [bar addSubview:blur];

    // Subtle inner highlight along the top edge (one-pixel hairline).
    UIView *highlight = [[UIView alloc] init];
    highlight.translatesAutoresizingMaskIntoConstraints = NO;
    highlight.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    highlight.layer.cornerRadius = 0.5;
    [blur.contentView addSubview:highlight];

    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [blur.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],

        [highlight.topAnchor constraintEqualToAnchor:blur.contentView.topAnchor constant:1.0],
        [highlight.leadingAnchor constraintEqualToAnchor:blur.contentView.leadingAnchor constant:18.0],
        [highlight.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor constant:-18.0],
        [highlight.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor constant:kSCIMediaChromeHorizontalMargin],
        [bar.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor constant:-kSCIMediaChromeHorizontalMargin],
        [bar.bottomAnchor constraintEqualToAnchor:hostView.safeAreaLayoutGuide.bottomAnchor constant:-kSCIMediaChromeBottomGap],
        [bar.heightAnchor constraintEqualToConstant:SCIMediaChromeBottomBarHeight],
    ]];

    return bar;
}

UIButton *SCIMediaChromeBottomButton(NSString *resourceName, NSString *accessibilityLabel) {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setImage:SCIMediaChromeBottomIcon(resourceName) forState:UIControlStateNormal];
    btn.tintColor = [UIColor labelColor];
    btn.accessibilityLabel = accessibilityLabel;
    btn.adjustsImageWhenHighlighted = NO;
    return btn;
}

UIStackView *SCIMediaChromeInstallBottomRow(UIView *bottomBar, NSArray<UIView *> *row) {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:row];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.alignment = UIStackViewAlignmentCenter;

    UIVisualEffectView *blur = (UIVisualEffectView *)bottomBar.subviews.firstObject;
    UIView *host = [blur isKindOfClass:UIVisualEffectView.class] ? blur.contentView : bottomBar;
    [host addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:host.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:6.0],
        [stack.trailingAnchor constraintEqualToAnchor:host.trailingAnchor constant:-6.0],
    ]];
    for (UIView *v in row) {
        [v.heightAnchor constraintEqualToConstant:SCIMediaChromeBottomBarHeight].active = YES;
    }

    return stack;
}
