#import "SCILinksSheet.h"
#import "../Localization/SCILocalization.h"
#import "../Tweak.h"
#import "../Utils.h"

@implementation SCILinksSheet

+ (void)presentFrom:(UIViewController *)source {
    SCILinksSheet *vc = [[SCILinksSheet alloc] init];
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = vc.sheetPresentationController;
    if (sheet) {
        sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent]];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 28;
    }
    [source presentViewController:vc animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.11 alpha:1.0]
            : [UIColor systemBackgroundColor];
    }];

    UIImageView *logo = [[UIImageView alloc] initWithImage:
        [UIImage imageNamed:@"ryukgram"
                   inBundle:SCILocalizationBundle()
      compatibleWithTraitCollection:nil]];
    logo.contentMode = UIViewContentModeScaleAspectFill;
    logo.clipsToBounds = YES;
    logo.layer.cornerRadius = 18;
    logo.layer.cornerCurve = kCACornerCurveContinuous;
    [logo.widthAnchor constraintEqualToConstant:78].active = YES;
    [logo.heightAnchor constraintEqualToConstant:78].active = YES;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"RyukGram";
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *version = [[UILabel alloc] init];
    version.text = SCIVersionString;
    version.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    version.textColor = [UIColor secondaryLabelColor];
    version.textAlignment = NSTextAlignmentCenter;

    UIButton *github = [self makeButtonWithTitle:SCILocalized(@"View on GitHub")
                                        sfSymbol:@"chevron.left.forwardslash.chevron.right"
                                            tint:[UIColor labelColor]
                                      background:[UIColor tertiarySystemFillColor]];
    [github addTarget:self action:@selector(openGitHub) forControlEvents:UIControlEventTouchUpInside];

    UIButton *telegram = [self makeButtonWithTitle:SCILocalized(@"Join Telegram channel")
                                          sfSymbol:@"paperplane.fill"
                                              tint:[UIColor whiteColor]
                                        background:[UIColor colorWithRed:0.15 green:0.56 blue:0.93 alpha:1.0]];
    [telegram addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[github, telegram]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 10;
    buttons.distribution = UIStackViewDistributionFillEqually;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[logo, title, version, buttons]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 14;
    [stack setCustomSpacing:2 afterView:title];
    [stack setCustomSpacing:22 afterView:version];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:g.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],
        [buttons.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    ]];
}

- (UIButton *)makeButtonWithTitle:(NSString *)title
                         sfSymbol:(NSString *)symbol
                             tint:(UIColor *)tint
                       background:(UIColor *)bg {
    UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.title = title;
    cfg.image = [UIImage systemImageNamed:symbol];
    cfg.imagePadding = 10;
    cfg.imagePlacement = NSDirectionalRectEdgeLeading;
    cfg.baseForegroundColor = tint;
    cfg.baseBackgroundColor = bg;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(14, 16, 14, 16);

    UIButton *b = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (void)openGitHub {
    NSURL *url = [NSURL URLWithString:SCIRepoURL];
    [self dismissViewControllerAnimated:YES completion:^{
        if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }];
}

- (void)openTelegram {
    UIApplication *app = [UIApplication sharedApplication];
    NSURL *scheme = [NSURL URLWithString:@"tg://resolve?domain=ryukgram"];
    NSURL *web = [NSURL URLWithString:@"https://t.me/ryukgram"];
    // IG's Info.plist doesn't whitelist `tg` for canOpenURL — skip the check
    // and fall through to the web link if the scheme isn't handled.
    [self dismissViewControllerAnimated:YES completion:^{
        [app openURL:scheme options:@{} completionHandler:^(BOOL ok) {
            if (!ok && web) [app openURL:web options:@{} completionHandler:nil];
        }];
    }];
}

@end
