#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import <objc/runtime.h>

// Long-press the color wheel on a music or lyric sticker → action sheet [Solid / Gradient] →
// bottom sheet with the system color picker (and Start/End swatches in gradient mode).

#pragma mark - Helpers

static UIColor *SCIGradientPatternColor(UIColor *start, UIColor *end, CGSize size) {
    if (size.width < 1 || size.height < 1) size = CGSizeMake(300, 60);
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)start.CGColor, (__bridge id)end.CGColor];
    CGFloat locations[2] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(ctx, gradient, CGPointZero, CGPointMake(size.width, 0), 0);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGGradientRelease(gradient);
    CGColorSpaceRelease(cs);
    return [UIColor colorWithPatternImage:img];
}

static void SCISetStickerColor(UIView *sticker, UIColor *color) {
    if (!sticker || !color) return;
    if ([sticker respondsToSelector:@selector(setColor:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(sticker, @selector(setColor:), color);
    }
}

static UIView *SCIFindDynamicRevealView(UIView *root) {
    if (!root) return nil;
    if ([NSStringFromClass([root class]) isEqualToString:@"IGDynamicRevealDynamicTextView"]) return root;
    for (UIView *sub in root.subviews) {
        UIView *hit = SCIFindDynamicRevealView(sub);
        if (hit) return hit;
    }
    return nil;
}

// Dual-label "dynamic reveal" lyric variant: setColor:patternImage breaks textColor rendering.
// Apply per-label gradient to the x=0 fill labels and leave the x=8 white highlights alone.
static BOOL SCIApplyDynamicRevealGradient(UIView *sticker, UIColor *start, UIColor *end) {
    UIView *dynView = SCIFindDynamicRevealView(sticker);
    if (!dynView) return NO;
    for (UIView *sub in dynView.subviews) {
        if (![sub isKindOfClass:[UILabel class]]) continue;
        UILabel *label = (UILabel *)sub;
        if (label.frame.origin.x > 0.5) continue;
        CGSize size = label.bounds.size;
        if (size.width < 1 || size.height < 1) continue;
        label.textColor = SCIGradientPatternColor(start, end, size);
        [label setNeedsDisplay];
    }
    return YES;
}

static void SCIScanForStickers(UIView *root, NSMutableArray *out) {
    if (!root) return;
    NSString *cls = NSStringFromClass([root class]);
    if (([cls containsString:@"Music"] || [cls containsString:@"Lyric"]) && [root respondsToSelector:@selector(setColor:)]) {
        [out addObject:root];
    }
    for (UIView *sub in root.subviews) SCIScanForStickers(sub, out);
}

static UIView *SCIFindMusicStickerNearWheel(UIView *wheel) {
    NSMutableArray *candidates = [NSMutableArray array];
    NSMutableArray *windows = [NSMutableArray array];
    if (wheel.window) [windows addObject:wheel.window];
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (![windows containsObject:w]) [windows addObject:w];
        }
    }
    for (UIWindow *w in windows) SCIScanForStickers(w, candidates);
    for (UIView *v in candidates) {
        if ([NSStringFromClass([v class]) containsString:@"Sticker"]) return v;
    }
    return candidates.firstObject;
}

#pragma mark - Sheet VC

typedef NS_ENUM(NSInteger, SCIMusicColorMode) {
    SCIMusicColorModeSolid = 0,
    SCIMusicColorModeGradient,
};

@interface SCIMusicColorSheetVC : UIViewController <UIColorPickerViewControllerDelegate>
@property (nonatomic, weak) UIView *targetSticker;
@property (nonatomic, assign) SCIMusicColorMode mode;
@property (nonatomic, strong) UIColor *startColor;
@property (nonatomic, strong) UIColor *endColor;
@property (nonatomic, assign) BOOL editingEndSlot;
@property (nonatomic, strong) UIColorPickerViewController *picker;
@property (nonatomic, strong) UIStackView *swatchRow;
@property (nonatomic, strong) UIButton *startSwatch;
@property (nonatomic, strong) UIButton *endSwatch;
@property (nonatomic, assign) CFTimeInterval lastApply;
@end

@implementation SCIMusicColorSheetVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    if (!_startColor) _startColor = [UIColor systemPinkColor];
    if (!_endColor) _endColor = [UIColor systemPurpleColor];

    [self buildSwatchRow];
    [self buildPicker];
    [self layout];
    [self refreshSwatches];
    [self applyToSticker];
}

- (void)buildSwatchRow {
    _startSwatch = [self makeSwatch];
    _endSwatch = [self makeSwatch];
    [_startSwatch addTarget:self action:@selector(selectStartSlot) forControlEvents:UIControlEventTouchUpInside];
    [_endSwatch addTarget:self action:@selector(selectEndSlot) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *startCol = [[UIStackView alloc] initWithArrangedSubviews:@[[self makeLabel:SCILocalized(@"Start")], _startSwatch]];
    startCol.axis = UILayoutConstraintAxisVertical; startCol.alignment = UIStackViewAlignmentCenter; startCol.spacing = 4;
    UIStackView *endCol = [[UIStackView alloc] initWithArrangedSubviews:@[[self makeLabel:SCILocalized(@"End")], _endSwatch]];
    endCol.axis = UILayoutConstraintAxisVertical; endCol.alignment = UIStackViewAlignmentCenter; endCol.spacing = 4;

    _swatchRow = [[UIStackView alloc] initWithArrangedSubviews:@[startCol, endCol]];
    _swatchRow.axis = UILayoutConstraintAxisHorizontal;
    _swatchRow.alignment = UIStackViewAlignmentCenter;
    _swatchRow.spacing = 32;
    _swatchRow.translatesAutoresizingMaskIntoConstraints = NO;
    _swatchRow.hidden = (_mode != SCIMusicColorModeGradient);
}

- (UIButton *)makeSwatch {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.layer.cornerRadius = 18;
    b.layer.masksToBounds = YES;
    b.layer.borderColor = UIColor.separatorColor.CGColor;
    b.layer.borderWidth = 2;
    [b.widthAnchor constraintEqualToConstant:36].active = YES;
    [b.heightAnchor constraintEqualToConstant:36].active = YES;
    return b;
}

- (UILabel *)makeLabel:(NSString *)text {
    UILabel *l = [UILabel new];
    l.text = text;
    l.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    l.textColor = UIColor.secondaryLabelColor;
    return l;
}

- (void)buildPicker {
    _picker = [[UIColorPickerViewController alloc] init];
    _picker.delegate = self;
    _picker.supportsAlpha = NO;
    _picker.selectedColor = _startColor;
    [_picker addObserver:self forKeyPath:@"selectedColor" options:NSKeyValueObservingOptionNew context:NULL];
    [self addChildViewController:_picker];
    _picker.view.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)layout {
    [self.view addSubview:_swatchRow];
    [self.view addSubview:_picker.view];
    [_picker didMoveToParentViewController:self];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    if (_mode == SCIMusicColorModeGradient) {
        [NSLayoutConstraint activateConstraints:@[
            [_swatchRow.topAnchor constraintEqualToAnchor:g.topAnchor constant:12],
            [_swatchRow.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
            [_picker.view.topAnchor constraintEqualToAnchor:_swatchRow.bottomAnchor constant:8],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [_picker.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        ]];
    }
    [NSLayoutConstraint activateConstraints:@[
        [_picker.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_picker.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_picker.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)refreshSwatches {
    _startSwatch.backgroundColor = _startColor;
    _endSwatch.backgroundColor = _endColor;
    _startSwatch.layer.borderColor = (_editingEndSlot ? UIColor.separatorColor : UIColor.labelColor).CGColor;
    _endSwatch.layer.borderColor = (_editingEndSlot ? UIColor.labelColor : UIColor.separatorColor).CGColor;
    _startSwatch.layer.borderWidth = _editingEndSlot ? 2 : 3;
    _endSwatch.layer.borderWidth = _editingEndSlot ? 3 : 2;
}

- (void)selectStartSlot {
    _editingEndSlot = NO;
    _picker.selectedColor = _startColor;
    [self refreshSwatches];
}

- (void)selectEndSlot {
    _editingEndSlot = YES;
    _picker.selectedColor = _endColor;
    [self refreshSwatches];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (![keyPath isEqualToString:@"selectedColor"]) return;
    UIColor *c = change[NSKeyValueChangeNewKey];
    if (![c isKindOfClass:[UIColor class]]) return;
    UIColor *opaque = [c colorWithAlphaComponent:1.0];

    if (_mode == SCIMusicColorModeGradient) {
        if (_editingEndSlot) _endColor = opaque; else _startColor = opaque;
    } else {
        _startColor = opaque;
    }
    [self refreshSwatches];
    [self applyToSticker];
}

- (void)applyToSticker {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _lastApply < 0.033) return;
    _lastApply = now;

    UIView *sticker = self.targetSticker;
    if (!sticker) return;

    if (_mode == SCIMusicColorModeGradient) {
        if (!SCIApplyDynamicRevealGradient(sticker, _startColor, _endColor)) {
            UIColor *pattern = SCIGradientPatternColor(_startColor, _endColor, sticker.bounds.size);
            SCISetStickerColor(sticker, pattern);
        }
    } else {
        SCISetStickerColor(sticker, _startColor);
    }
}

- (void)dealloc {
    @try { [_picker removeObserver:self forKeyPath:@"selectedColor"]; }
    @catch (__unused NSException *e) {}
}

@end

#pragma mark - Hook

@interface IGStoryColorPaletteWheel (SCIMusicColor)
- (void)sciHandleLongPress:(UILongPressGestureRecognizer *)sender;
- (void)sciPresentSheetWithMode:(SCIMusicColorMode)mode sticker:(UIView *)sticker presenter:(UIViewController *)presenter;
@end

%hook IGStoryColorPaletteWheel

- (void)didMoveToWindow {
    %orig;
    if ([SCIUtils getBoolPref:@"custom_music_sticker_color"]) {
        [self addLongPressGestureRecognizer];
    }
}

%new
- (void)addLongPressGestureRecognizer {
    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) return;
    }
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sciHandleLongPress:)];
    lp.minimumPressDuration = 0.25;
    [self addGestureRecognizer:lp];
}

%new
- (void)sciHandleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    UIView *sticker = SCIFindMusicStickerNearWheel(self);
    if (!sticker) return;
    UIViewController *presenter = [SCIUtils nearestViewControllerForView:self];
    if (!presenter) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:SCILocalized(@"Custom music sticker color")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Solid color")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_a) {
        [self sciPresentSheetWithMode:SCIMusicColorModeSolid sticker:sticker presenter:presenter];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Gradient color")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_a) {
        [self sciPresentSheetWithMode:SCIMusicColorModeGradient sticker:sticker presenter:presenter];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;
    }

    [presenter presentViewController:sheet animated:YES completion:nil];
}

%new
- (void)sciPresentSheetWithMode:(SCIMusicColorMode)mode sticker:(UIView *)sticker presenter:(UIViewController *)presenter {
    SCIMusicColorSheetVC *vc = [[SCIMusicColorSheetVC alloc] init];
    vc.targetSticker = sticker;
    vc.mode = mode;
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *s = vc.sheetPresentationController;
        if (s) {
            s.detents = @[[UISheetPresentationControllerDetent mediumDetent],
                          [UISheetPresentationControllerDetent largeDetent]];
            s.prefersGrabberVisible = YES;
            s.preferredCornerRadius = 16.0;
        }
    }
    [presenter presentViewController:vc animated:YES completion:nil];
}

%end
