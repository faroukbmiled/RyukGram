#import "SCIGallerySheetViewController.h"

static CGFloat const kSheetCardCornerRadius = 22.0;
static CGFloat const kSheetCardTitleHeight  = 40.0;

@interface SCIGallerySheetViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong, readwrite) UIView *card;
@property (nonatomic, strong, readwrite) UIScrollView *scrollView;
@property (nonatomic, strong, readwrite) UIStackView *contentStack;
@property (nonatomic, strong) UIView *backdrop;
@property (nonatomic, strong) UIView *grabber;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSLayoutConstraint *cardBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cardHeightConstraint;
@property (nonatomic, assign) CGFloat compactHeight;
@property (nonatomic, assign) CGFloat maxHeight;
@property (nonatomic, assign) CGFloat panStartHeight;
@property (nonatomic, assign) CGFloat panStartBottomOffset;
@end

@implementation SCIGallerySheetViewController

- (instancetype)init {
    if ((self = [super init])) {
        // Card animation is owned by us. Present unanimated so we don't pay
        // for the system cross-dissolve before our spring kicks in.
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    return self;
}

- (CGFloat)preferredCardHeight {
    CGFloat screen = UIScreen.mainScreen.bounds.size.height;
    return MAX(330.0, MIN(430.0, screen * 0.60));
}

- (CGFloat)maxCardHeight {
    CGFloat screen = UIScreen.mainScreen.bounds.size.height;
    return screen * 0.92;
}

// MARK: - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    [self setupBackdrop];
    [self setupCard];
    [self setupGrabber];
    [self setupTitleLabel];
    [self setupContent];
    [self setupGestures];
}

- (void)setupBackdrop {
    _backdrop = [UIView new];
    _backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    _backdrop.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    _backdrop.alpha = 0.0;
    [self.view addSubview:_backdrop];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped)];
    [_backdrop addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [_backdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_backdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_backdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_backdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)setupCard {
    _card = [UIView new];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    _card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _card.opaque = YES;
    _card.layer.cornerRadius = kSheetCardCornerRadius;
    _card.layer.cornerCurve = kCACornerCurveContinuous;
    _card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    _card.clipsToBounds = YES;
    [self.view addSubview:_card];

    _compactHeight = [self preferredCardHeight];
    _maxHeight = MAX(_compactHeight, [self maxCardHeight]);
    _cardBottomConstraint = [_card.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:_compactHeight];
    _cardHeightConstraint = [_card.heightAnchor constraintEqualToConstant:_compactHeight];
    [NSLayoutConstraint activateConstraints:@[
        [_card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        _cardBottomConstraint,
        _cardHeightConstraint,
    ]];
}

- (void)setupGrabber {
    _grabber = [UIView new];
    _grabber.translatesAutoresizingMaskIntoConstraints = NO;
    _grabber.backgroundColor = [UIColor systemFillColor];
    _grabber.layer.cornerRadius = 2.5;
    [_card addSubview:_grabber];

    [NSLayoutConstraint activateConstraints:@[
        [_grabber.topAnchor constraintEqualToAnchor:_card.topAnchor constant:8.0],
        [_grabber.centerXAnchor constraintEqualToAnchor:_card.centerXAnchor],
        [_grabber.widthAnchor constraintEqualToConstant:36.0],
        [_grabber.heightAnchor constraintEqualToConstant:5.0],
    ]];
}

- (void)setupTitleLabel {
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = [UIColor labelColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.text = self.sheetTitle ?: @"";
    [_card addSubview:_titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:_card.topAnchor constant:18.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-16.0],
        [_titleLabel.heightAnchor constraintEqualToConstant:kSheetCardTitleHeight - 18.0],
    ]];
}

- (void)setupContent {
    _scrollView = [UIScrollView new];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.backgroundColor = [UIColor clearColor];
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    [_card addSubview:_scrollView];

    _contentStack = [UIStackView new];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 10.0;
    [_scrollView addSubview:_contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8.0],
        [_scrollView.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor],

        [_contentStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:8.0],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.leadingAnchor constant:16.0],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.trailingAnchor constant:-16.0],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-24.0],
    ]];
}

- (void)setupGestures {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    [_card addGestureRecognizer:pan];
}

// MARK: - Title sync

- (void)setSheetTitle:(NSString *)sheetTitle {
    _sheetTitle = [sheetTitle copy];
    self.titleLabel.text = sheetTitle ?: @"";
}

// MARK: - Animate in / out

// Called by the gallery presenter via [presentViewController:animated:NO].
// We start the spring animation directly so the card slides up immediately
// without waiting on a system transition.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.cardBottomConstraint.constant != 0.0) {
        [self.view layoutIfNeeded];
        self.cardBottomConstraint.constant = 0.0;
        [UIView animateWithDuration:0.28
                              delay:0.0
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.backdrop.alpha = 1.0;
            [self.view layoutIfNeeded];
        } completion:nil];
    }
}

- (void)dismissAnimated {
    [self.view layoutIfNeeded];
    self.cardBottomConstraint.constant = self.cardHeightConstraint.constant;
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.backdrop.alpha = 0.0;
        [self.view layoutIfNeeded];
    } completion:^(__unused BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (void)backdropTapped {
    [self dismissAnimated];
}

// MARK: - Pan to resize / dismiss

// Drag UP grows the card up to maxCardHeight. Drag DOWN past the threshold
// dismisses; otherwise snaps back to compact height.
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGFloat dy = [pan translationInView:self.view].y;
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            self.panStartHeight = self.cardHeightConstraint.constant;
            self.panStartBottomOffset = self.cardBottomConstraint.constant;
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (dy < 0) {
                // Pulling up — grow the card up to maxHeight.
                CGFloat target = MIN(self.maxHeight, self.panStartHeight - dy);
                self.cardHeightConstraint.constant = target;
                self.cardBottomConstraint.constant = 0.0;
                self.backdrop.alpha = 1.0;
            } else {
                // Pulling down — translate the card off-screen.
                self.cardHeightConstraint.constant = self.panStartHeight;
                self.cardBottomConstraint.constant = self.panStartBottomOffset + dy;
                CGFloat dismissProgress = MIN(1.0, dy / self.panStartHeight);
                self.backdrop.alpha = 1.0 - dismissProgress * 0.85;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat velocity = [pan velocityInView:self.view].y;
            CGFloat bottomOffset = self.cardBottomConstraint.constant;
            BOOL shouldDismiss = (bottomOffset > self.panStartHeight * 0.30) || velocity > 800.0;
            if (shouldDismiss) {
                [self dismissAnimated];
            } else {
                // Settle: card height stays at whatever it grew to, bottom offset = 0.
                self.cardBottomConstraint.constant = 0.0;
                [UIView animateWithDuration:0.25
                                      delay:0.0
                     usingSpringWithDamping:0.9
                      initialSpringVelocity:0.3
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                    self.backdrop.alpha = 1.0;
                    [self.view layoutIfNeeded];
                } completion:nil];
            }
            break;
        }
        default: break;
    }
}

// Pan should defer to scroll view drags when the scroll view has content
// above the top — only intercept when the user starts dragging from the
// title area or from a top-of-scroll position.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) return YES;
    CGPoint loc = [touch locationInView:self.scrollView];
    if (CGRectContainsPoint(self.scrollView.bounds, loc) && self.scrollView.contentOffset.y > 0) {
        return NO;
    }
    return YES;
}

// MARK: - Content API

- (void)addSectionTitle:(NSString *)title {
    UILabel *label = [UILabel new];
    label.text = [title uppercaseString];
    label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor secondaryLabelColor];
    [self.contentStack addArrangedSubview:label];
    [self.contentStack setCustomSpacing:6.0 afterView:label];
}

- (void)addCardRow:(UIView *)row {
    [self.contentStack addArrangedSubview:row];
    [self.contentStack setCustomSpacing:14.0 afterView:row];
}

- (void)addContentView:(UIView *)view {
    [self.contentStack addArrangedSubview:view];
    [self.contentStack setCustomSpacing:14.0 afterView:view];
}

@end
