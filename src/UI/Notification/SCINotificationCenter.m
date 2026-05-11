#import "SCINotificationCenter.h"
#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// ───── Pref keys (mirrored in SCIDefaultsDictionary in SCIDefaults.m) ─────
static NSString *const kPrefStyle           = @"notif_style";
static NSString *const kPrefPosition        = @"notif_position";
static NSString *const kPrefDefaultSurface  = @"notif_default_surface";
static NSString *const kPrefMaxVisible      = @"notif_max_visible";
static NSString *const kPrefHaptics         = @"notif_haptics";
static NSString *const kPrefDuration        = @"notif_duration";
static NSString *const kPrefMaster          = @"notif_master_enabled";
static NSString *const kPerActionPrefix     = @"notif_action_";

static const NSTimeInterval kDefaultToastDuration = 1.8;
static const NSTimeInterval kErrorToastDuration   = 2.6;
static const NSTimeInterval kTerminalLinger       = 1.2;
static const CGFloat        kStackSpacing         = 8.0;
static const NSUInteger     kHardMaxVisible       = 3;

// Spring + slide tuning for entrance / dismiss / restack.
static const NSTimeInterval kInsertDuration   = 0.55;
static const CGFloat        kInsertDamping    = 0.78;
static const CGFloat        kInsertVelocity   = 0.7;
static const CGFloat        kEntranceSlide    = 80.0;
static const CGFloat        kEntranceScale    = 0.9;
static const NSTimeInterval kDismissDuration  = 0.28;
static const CGFloat        kDismissSlide     = 60.0;
static const CGFloat        kDismissScale     = 0.92;
static const NSTimeInterval kRelayoutDuration = 0.32;
static const CGFloat        kRelayoutDamping  = 0.82;
static const CGFloat        kRelayoutVelocity = 0.5;

// ───── Surface routing ─────
typedef NS_ENUM(NSUInteger, SCINotifSurface) {
    SCINotifSurfacePill,
    SCINotifSurfaceIGNative,
    SCINotifSurfaceOff,
};

static SCINotifSurface SCINotifSurfaceFromString(NSString *s, SCINotifSurface fallback) {
    if ([s isEqualToString:@"pill"])      return SCINotifSurfacePill;
    if ([s isEqualToString:@"ig_native"]) return SCINotifSurfaceIGNative;
    if ([s isEqualToString:@"off"])       return SCINotifSurfaceOff;
    return fallback;
}

static SCINotificationStyle SCINotifStyleFromString(NSString *s) {
    if ([s isEqualToString:@"colorful"]) return SCINotificationStyleColorful;
    if ([s isEqualToString:@"glow"])     return SCINotificationStyleGlow;
    if ([s isEqualToString:@"island"])   return SCINotificationStyleIsland;
    return SCINotificationStyleMinimal;
}

static SCINotificationPosition SCINotifPositionFromString(NSString *s) {
    return [s isEqualToString:@"bottom"] ? SCINotificationPositionBottom : SCINotificationPositionTop;
}

@interface SCINotifSlot : NSObject
@property (nonatomic, strong) SCINotificationPillView *pill;
@property (nonatomic, strong) NSLayoutConstraint *anchorConstraint;
@property (nonatomic, copy)   NSString *actionID;
@property (nonatomic, assign) BOOL terminal;
@property (nonatomic, assign) BOOL isProgress;
@property (nonatomic, strong) NSTimer *autoDismissTimer;
@property (nonatomic, weak)   SCINotificationHandle *handle;
@end

@implementation SCINotifSlot @end


@interface SCINotificationHandle ()
@property (nonatomic, copy, readwrite) NSString *actionID;
@property (nonatomic, assign, readwrite) BOOL isFinished;
@property (nonatomic, weak) SCINotifSlot *slot;
@property (nonatomic, weak) SCINotificationCenter *center;
@end


@interface SCINotificationCenter () {
    NSMutableArray<SCINotifSlot *> *_visible;
    NSMutableArray<NSDictionary *> *_queue;       // overflow when stack is full
    UINotificationFeedbackGenerator *_notifGen;
    UIImpactFeedbackGenerator *_impactGen;
}

// Cross-file private — used by SCINotificationHandle.
- (void)sciHandleSetProgress:(float)progress slot:(SCINotifSlot *)slot;
- (void)sciHandleSetIndeterminate:(BOOL)indeterminate slot:(SCINotifSlot *)slot;
- (void)sciHandleSetTitle:(NSString *)title subtitle:(NSString *)subtitle slot:(SCINotifSlot *)slot;
- (void)sciHandleTerminate:(SCINotifSlot *)slot tone:(SCINotificationTone)tone title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon;
- (void)sciHandleDismiss:(SCINotifSlot *)slot;
@end

@implementation SCINotificationCenter

+ (instancetype)shared {
    static SCINotificationCenter *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [SCINotificationCenter new]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _visible = [NSMutableArray new];
    _queue = [NSMutableArray new];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sciAppBackgrounded)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    return self;
}

#pragma mark - Settings (read fresh per call — no caching)

- (SCINotificationStyle)sciCurrentStyle {
    return SCINotifStyleFromString([SCIUtils getStringPref:kPrefStyle]);
}

- (SCINotificationPosition)sciCurrentPosition {
    return SCINotifPositionFromString([SCIUtils getStringPref:kPrefPosition]);
}

- (BOOL)sciMasterEnabled {
    return [SCIUtils getBoolPref:kPrefMaster];
}

- (BOOL)sciHapticsEnabled {
    return [SCIUtils getBoolPref:kPrefHaptics];
}

- (double)sciDurationMultiplier {
    double d = [SCIUtils getDoublePref:kPrefDuration];
    return (d > 0.01) ? d : 1.0;
}

- (NSUInteger)sciMaxVisible {
    double d = [SCIUtils getDoublePref:kPrefMaxVisible];
    NSUInteger n = (d > 0.5) ? (NSUInteger)d : 2;
    return MAX(1, MIN(n, kHardMaxVisible));
}

- (SCINotifSurface)sciDefaultSurface {
    return SCINotifSurfaceFromString([SCIUtils getStringPref:kPrefDefaultSurface], SCINotifSurfacePill);
}

- (SCINotifSurface)sciSurfaceForAction:(NSString *)actionID isProgress:(BOOL)isProgress {
    if (![self sciMasterEnabled]) return SCINotifSurfaceOff;

    NSString *override = [SCIUtils getStringPref:[kPerActionPrefix stringByAppendingString:actionID ?: @""]];
    SCINotifSurface s = SCINotifSurfaceFromString(override, [self sciDefaultSurface]);

    // IG-native has no progress affordance; fall back to pill.
    if (s == SCINotifSurfaceIGNative && isProgress) return SCINotifSurfacePill;
    SCINotificationActionInfo *info = SCINotificationActionInfoForID(actionID);
    if (info && !(info.caps & SCINotificationActionCapsAllowIG) && s == SCINotifSurfaceIGNative) {
        return SCINotifSurfacePill;
    }
    return s;
}

#pragma mark - Public toast

- (void)notifyAction:(NSString *)actionID
               title:(NSString *)title
            subtitle:(NSString *)subtitle
                icon:(NSString *)iconSymbol
                tone:(SCINotificationTone)tone {
    NSTimeInterval base = (tone == SCINotificationToneError) ? kErrorToastDuration : kDefaultToastDuration;
    [self notifyAction:actionID title:title subtitle:subtitle icon:iconSymbol tone:tone duration:base];
}

- (void)notifyAction:(NSString *)actionID
               title:(NSString *)title
            subtitle:(NSString *)subtitle
                icon:(NSString *)iconSymbol
                tone:(SCINotificationTone)tone
            duration:(NSTimeInterval)duration {
    SCINotifSurface surface = [self sciSurfaceForAction:actionID isProgress:NO];
    if (surface == SCINotifSurfaceOff) return;

    if (surface == SCINotifSurfaceIGNative) {
        NSTimeInterval igEffective = MAX(0.6, duration * [self sciDurationMultiplier]);
        [self sciOnMain:^{ [SCIUtils showIGNativeToastForDuration:igEffective title:title subtitle:subtitle]; }];
        return;
    }

    [self sciOnMain:^{
        [self sciPresentToastForAction:actionID title:title subtitle:subtitle icon:iconSymbol tone:tone duration:duration];
    }];
}

- (void)notifyError:(NSString *)actionID title:(NSString *)title message:(NSString *)message {
    [self notifyAction:actionID title:title subtitle:message icon:@"exclamationmark.triangle.fill" tone:SCINotificationToneError];
}

#pragma mark - Public progress

- (SCINotificationHandle *)beginProgressForAction:(NSString *)actionID title:(NSString *)title onCancel:(void (^)(void))onCancel {
    return [self sciBeginProgressForAction:actionID title:title indeterminate:NO icon:@"arrow.down.to.line" onCancel:onCancel];
}

- (SCINotificationHandle *)beginLoadingForAction:(NSString *)actionID title:(NSString *)title onCancel:(void (^)(void))onCancel {
    return [self sciBeginProgressForAction:actionID title:title indeterminate:YES icon:@"hourglass" onCancel:onCancel];
}

- (SCINotificationHandle *)sciBeginProgressForAction:(NSString *)actionID
                                                title:(NSString *)title
                                        indeterminate:(BOOL)indeterminate
                                                 icon:(NSString *)icon
                                             onCancel:(void (^)(void))onCancel {
    SCINotifSurface surface = [self sciSurfaceForAction:actionID isProgress:YES];
    if (surface == SCINotifSurfaceOff) return nil;

    __block SCINotificationHandle *handle = [SCINotificationHandle new];
    handle.actionID = actionID;
    handle.center = self;

    void (^onCancelCopy)(void) = [onCancel copy];

    [self sciOnMain:^{
        SCINotifSlot *slot = [self sciCreateSlotForAction:actionID title:title subtitle:nil icon:icon tone:SCINotificationToneInfo isProgress:YES];
        slot.handle = handle;
        slot.pill.showsProgress = YES;
        slot.pill.indeterminate = indeterminate;
        slot.pill.showsCancelButton = (onCancelCopy != nil);
        slot.pill.onCancel = ^(SCINotificationPillView *pill) {
            (void)pill;
            if (onCancelCopy) onCancelCopy();
        };
        handle.slot = slot;
        [slot.pill refreshSizeAnimated:NO];

        [self sciInsertSlot:slot animated:YES];
    }];
    return handle;
}

#pragma mark - Stack mgmt

- (void)sciPresentToastForAction:(NSString *)actionID title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon tone:(SCINotificationTone)tone duration:(NSTimeInterval)duration {
    NSTimeInterval effective = MAX(0.6, duration * [self sciDurationMultiplier]);
    if (_visible.count >= [self sciMaxVisible]) {
        [_queue addObject:@{
            @"actionID": actionID ?: @"",
            @"title":    title ?: @"",
            @"subtitle": subtitle ?: @"",
            @"icon":     icon ?: @"",
            @"tone":     @(tone),
            @"duration": @(duration),
        }];
        return;
    }

    SCINotifSlot *slot = [self sciCreateSlotForAction:actionID title:title subtitle:subtitle icon:icon tone:tone isProgress:NO];
    [slot.pill refreshSizeAnimated:NO];
    [self sciInsertSlot:slot animated:YES];

    __weak SCINotifSlot *weakSlot = slot;
    slot.autoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:effective repeats:NO block:^(__unused NSTimer *t) {
        SCINotifSlot *strong = weakSlot;
        if (strong) [self sciDismissSlot:strong animated:YES];
    }];
}

- (SCINotifSlot *)sciCreateSlotForAction:(NSString *)actionID title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon tone:(SCINotificationTone)tone isProgress:(BOOL)isProgress {
    SCINotificationPillView *pill = [[SCINotificationPillView alloc] initWithStyle:[self sciCurrentStyle] position:[self sciCurrentPosition]];
    pill.titleText = title ?: @"";
    pill.subtitleText = subtitle;
    pill.iconSymbolName = icon;
    [pill applyTone:tone animated:NO];

    SCINotifSlot *slot = [SCINotifSlot new];
    slot.pill = pill;
    slot.actionID = actionID;
    slot.isProgress = isProgress;

    __weak typeof(self) weakSelf = self;
    __weak SCINotifSlot *weakSlot = slot;
    pill.onTap = ^(__unused SCINotificationPillView *p) {
        SCINotifSlot *s = weakSlot;
        if (s && !s.isProgress) [weakSelf sciDismissSlot:s animated:YES];
    };
    pill.onSwipeDismiss = ^(__unused SCINotificationPillView *p) {
        SCINotifSlot *s = weakSlot;
        if (s) [weakSelf sciDismissSlot:s animated:YES];
    };

    return slot;
}

- (UIView *)sciHostView {
    UIWindow *keyWin = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) { keyWin = w; break; }
        }
        if (keyWin) break;
    }
    if (!keyWin) keyWin = UIApplication.sharedApplication.keyWindow;
    return keyWin ?: topMostController().view;
}

- (void)sciInsertSlot:(SCINotifSlot *)slot animated:(BOOL)animated {
    UIView *host = [self sciHostView];
    if (!host) return;

    SCINotificationPillView *pill = slot.pill;
    [host addSubview:pill];
    [pill refreshSizeAnimated:NO];

    BOOL bottom = ([self sciCurrentPosition] == SCINotificationPositionBottom);
    NSLayoutConstraint *anchor;
    CGFloat anchorOffset = [self sciOffsetForPosition:bottom slotIndex:_visible.count];

    if (bottom) {
        anchor = [pill.bottomAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.bottomAnchor constant:-anchorOffset];
    } else {
        anchor = [pill.topAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.topAnchor constant:anchorOffset];
    }
    anchor.active = YES;
    [pill.centerXAnchor constraintEqualToAnchor:host.centerXAnchor].active = YES;
    slot.anchorConstraint = anchor;

    [_visible addObject:slot];
    [self sciHapticForTone:slot.pill.tone];

    [host layoutIfNeeded];

    CGFloat slideY = bottom ? kEntranceSlide : -kEntranceSlide;
    pill.alpha = 0.0;
    pill.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(kEntranceScale, kEntranceScale),
                                             CGAffineTransformMakeTranslation(0, slideY));

    [UIView animateWithDuration:kInsertDuration
                          delay:0
         usingSpringWithDamping:kInsertDamping
          initialSpringVelocity:kInsertVelocity
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        pill.alpha = 1.0;
        pill.transform = CGAffineTransformIdentity;
        [self sciRelayoutVisibleAnimated:NO host:host];
    } completion:nil];
}

- (CGFloat)sciOffsetForPosition:(BOOL)bottom slotIndex:(NSUInteger)idx {
    CGFloat baseMargin = 8.0;
    CGFloat acc = baseMargin;
    NSUInteger n = MIN(idx, _visible.count);
    for (NSUInteger i = 0; i < n; i++) {
        SCINotifSlot *s = bottom ? _visible[_visible.count - 1 - i] : _visible[i];
        CGFloat h = s.pill.bounds.size.height;
        if (h <= 1.0) h = 50.0;
        acc += h + kStackSpacing;
    }
    return acc;
}

- (void)sciRelayoutVisibleAnimated:(BOOL)animated host:(UIView *)host {
    BOOL bottom = ([self sciCurrentPosition] == SCINotificationPositionBottom);
    CGFloat acc = 8.0;
    NSArray<SCINotifSlot *> *order = bottom ? _visible.reverseObjectEnumerator.allObjects : _visible;
    for (SCINotifSlot *s in order) {
        s.anchorConstraint.constant = bottom ? -acc : acc;
        CGFloat h = s.pill.bounds.size.height;
        if (h <= 1.0) h = 50.0;
        acc += h + kStackSpacing;
    }

    if (animated) {
        [UIView animateWithDuration:kRelayoutDuration
                              delay:0
             usingSpringWithDamping:kRelayoutDamping
              initialSpringVelocity:kRelayoutVelocity
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            [host layoutIfNeeded];
        } completion:nil];
    }
}

- (void)sciDismissSlot:(SCINotifSlot *)slot animated:(BOOL)animated {
    if (!slot || ![_visible containsObject:slot]) return;
    [slot.autoDismissTimer invalidate];
    slot.autoDismissTimer = nil;

    BOOL bottom = ([self sciCurrentPosition] == SCINotificationPositionBottom);
    SCINotificationPillView *pill = slot.pill;

    void (^cleanup)(void) = ^{
        [pill removeFromSuperview];
        [self->_visible removeObject:slot];
        UIView *host = [self sciHostView];
        [self sciRelayoutVisibleAnimated:YES host:host];
        [self sciDrainQueueIfPossible];
    };

    if (!animated) { cleanup(); return; }

    [UIView animateWithDuration:kDismissDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        pill.alpha = 0.0;
        pill.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(kDismissScale, kDismissScale),
                                                 CGAffineTransformMakeTranslation(0, bottom ? kDismissSlide : -kDismissSlide));
    } completion:^(__unused BOOL done) {
        cleanup();
    }];
}

- (void)sciDrainQueueIfPossible {
    while (_visible.count < [self sciMaxVisible] && _queue.count > 0) {
        NSDictionary *next = _queue.firstObject;
        [_queue removeObjectAtIndex:0];
        [self sciPresentToastForAction:next[@"actionID"]
                                  title:next[@"title"]
                               subtitle:[next[@"subtitle"] length] ? next[@"subtitle"] : nil
                                   icon:[next[@"icon"] length] ? next[@"icon"] : nil
                                   tone:(SCINotificationTone)[next[@"tone"] unsignedIntegerValue]
                               duration:[next[@"duration"] doubleValue]];
    }
}

- (void)dismissAll {
    [self sciOnMain:^{
        for (SCINotifSlot *s in self->_visible.copy) {
            [self sciDismissSlot:s animated:NO];
        }
        [self->_queue removeAllObjects];
    }];
}

- (void)sciAppBackgrounded {
    [self dismissAll];
}

#pragma mark - Defaults registration

+ (NSDictionary<NSString *, NSString *> *)defaultPerActionPrefs {
    NSMutableDictionary *m = [NSMutableDictionary new];
    for (SCINotificationActionInfo *info in SCINotificationActionsAll()) {
        m[[@"notif_action_" stringByAppendingString:info.identifier]] = @"default";
    }
    return [m copy];
}

#pragma mark - Preview

- (void)presentPreviewDownloadEndingWithError:(BOOL)endWithError {
    [self sciOnMain:^{
        SCINotificationHandle *h = [self beginProgressForAction:SCI_NOTIF_DOWNLOAD
                                                          title:SCILocalized(@"Preview download…")
                                                       onCancel:nil];
        if (!h) return;
        NSArray<NSNumber *> *steps = @[@0.25, @0.55, @0.80, @1.00];
        for (NSUInteger i = 0; i < steps.count; i++) {
            float p = steps[i].floatValue;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.5 + i * 0.5) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [h setProgress:p];
            });
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (endWithError) {
                [h error:SCILocalized(@"Download failed") subtitle:SCILocalized(@"Tap to retry")];
            } else {
                [h success:SCILocalized(@"Saved") subtitle:SCILocalized(@"Saved to Photos")];
            }
        });
    }];
}

- (void)presentPreviewLoadingEndingWithError:(BOOL)endWithError {
    [self sciOnMain:^{
        SCINotificationHandle *h = [self beginLoadingForAction:SCI_NOTIF_GENERIC
                                                          title:[SCILocalized(@"Loading") stringByAppendingString:@"…"]
                                                       onCancel:nil];
        if (!h) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (endWithError) [h error:SCILocalized(@"Failed") subtitle:nil];
            else              [h success:SCILocalized(@"Done") subtitle:nil];
        });
    }];
}

- (void)presentPreviewWithTone:(SCINotificationTone)tone {
    NSString *title, *subtitle, *icon;
    switch (tone) {
        case SCINotificationToneSuccess:
            title = SCILocalized(@"Success preview"); subtitle = SCILocalized(@"Looks great"); icon = @"checkmark.circle.fill"; break;
        case SCINotificationToneError:
            title = SCILocalized(@"Error preview"); subtitle = SCILocalized(@"Something broke"); icon = @"exclamationmark.triangle.fill"; break;
        case SCINotificationToneWarning:
            title = SCILocalized(@"Warning preview"); subtitle = SCILocalized(@"Heads up"); icon = @"exclamationmark.circle.fill"; break;
        case SCINotificationToneInfo:
        default:
            title = SCILocalized(@"Info preview"); subtitle = SCILocalized(@"Just so you know"); icon = @"info.circle.fill"; break;
    }
    // Bypass routing — preview must always show our pill.
    [self sciOnMain:^{
        [self sciPresentToastForAction:SCI_NOTIF_GENERIC title:title subtitle:subtitle icon:icon tone:tone duration:2.0];
    }];
}

#pragma mark - Haptics

- (void)sciHapticForTone:(SCINotificationTone)tone {
    if (![self sciHapticsEnabled]) return;
    if (tone == SCINotificationToneSuccess || tone == SCINotificationToneError) {
        if (!_notifGen) _notifGen = [UINotificationFeedbackGenerator new];
        UINotificationFeedbackType t = (tone == SCINotificationToneSuccess) ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError;
        [_notifGen notificationOccurred:t];
    } else {
        if (!_impactGen) _impactGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [_impactGen impactOccurred];
    }
}

#pragma mark - Threading

- (void)sciOnMain:(dispatch_block_t)block {
    if (!block) return;
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

#pragma mark - Handle bridging

- (void)sciHandleSetProgress:(float)progress slot:(SCINotifSlot *)slot {
    [self sciOnMain:^{
        if (!slot || slot.terminal) return;
        [slot.pill setProgress:progress animated:YES];
    }];
}

- (void)sciHandleSetIndeterminate:(BOOL)indeterminate slot:(SCINotifSlot *)slot {
    [self sciOnMain:^{
        if (!slot || slot.terminal) return;
        slot.pill.indeterminate = indeterminate;
    }];
}

- (void)sciHandleSetTitle:(NSString *)title subtitle:(NSString *)subtitle slot:(SCINotifSlot *)slot {
    [self sciOnMain:^{
        if (!slot || slot.terminal) return;
        if (title) slot.pill.titleText = title;
        slot.pill.subtitleText = subtitle;
        [slot.pill refreshSizeAnimated:YES];
    }];
}

- (void)sciHandleTerminate:(SCINotifSlot *)slot tone:(SCINotificationTone)tone title:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon {
    [self sciOnMain:^{
        if (!slot || slot.terminal) return;
        slot.terminal = YES;
        slot.pill.showsProgress = NO;
        slot.pill.showsCancelButton = NO;
        slot.pill.onCancel = nil;
        slot.pill.iconSymbolName = icon;
        if (title) slot.pill.titleText = title;
        slot.pill.subtitleText = subtitle;
        [slot.pill applyTone:tone animated:YES];
        [slot.pill refreshSizeAnimated:YES];
        [slot.pill pulseIcon];
        [self sciHapticForTone:tone];

        __weak SCINotifSlot *weakSlot = slot;
        slot.autoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:kTerminalLinger repeats:NO block:^(__unused NSTimer *t) {
            SCINotifSlot *s = weakSlot;
            if (s) [self sciDismissSlot:s animated:YES];
        }];
    }];
}

- (void)sciHandleDismiss:(SCINotifSlot *)slot {
    [self sciOnMain:^{ [self sciDismissSlot:slot animated:YES]; }];
}

@end


// ───── Handle implementation ─────
@implementation SCINotificationHandle

- (void)setProgress:(float)progress {
    if (self.isFinished) return;
    [self.center sciHandleSetProgress:progress slot:self.slot];
}

- (void)setIndeterminate:(BOOL)indeterminate {
    if (self.isFinished) return;
    [self.center sciHandleSetIndeterminate:indeterminate slot:self.slot];
}

- (void)setTitle:(NSString *)title {
    if (self.isFinished) return;
    [self.center sciHandleSetTitle:title subtitle:self.slot.pill.subtitleText slot:self.slot];
}

- (void)setSubtitle:(NSString *)subtitle {
    if (self.isFinished) return;
    [self.center sciHandleSetTitle:self.slot.pill.titleText subtitle:subtitle slot:self.slot];
}

- (void)success:(NSString *)title { [self success:title subtitle:nil]; }

- (void)success:(NSString *)title subtitle:(NSString *)subtitle {
    if (self.isFinished) return;
    self.isFinished = YES;
    [self.center sciHandleTerminate:self.slot tone:SCINotificationToneSuccess title:title ?: SCILocalized(@"Done") subtitle:subtitle icon:@"checkmark.circle.fill"];
}

- (void)error:(NSString *)title { [self error:title subtitle:nil]; }

- (void)error:(NSString *)title subtitle:(NSString *)subtitle {
    if (self.isFinished) return;
    self.isFinished = YES;
    [self.center sciHandleTerminate:self.slot tone:SCINotificationToneError title:title ?: SCILocalized(@"Failed") subtitle:subtitle icon:@"exclamationmark.triangle.fill"];
}

- (void)cancelled:(NSString *)title {
    if (self.isFinished) return;
    self.isFinished = YES;
    [self.center sciHandleTerminate:self.slot tone:SCINotificationToneWarning title:title ?: SCILocalized(@"Cancelled") subtitle:nil icon:@"xmark.circle.fill"];
}

- (void)dismiss {
    if (self.isFinished) return;
    self.isFinished = YES;
    [self.center sciHandleDismiss:self.slot];
}

@end


// ───── C convenience ─────
void SCINotify(NSString *actionID, NSString *title, NSString *subtitle, NSString *iconSymbol, SCINotificationTone tone) {
    [[SCINotificationCenter shared] notifyAction:actionID title:title subtitle:subtitle icon:iconSymbol tone:tone];
}

void SCINotifySuccess(NSString *actionID, NSString *title, NSString *subtitle) {
    SCINotify(actionID, title, subtitle, @"checkmark.circle.fill", SCINotificationToneSuccess);
}

void SCINotifyInfo(NSString *actionID, NSString *title, NSString *subtitle) {
    SCINotify(actionID, title, subtitle, @"info.circle.fill", SCINotificationToneInfo);
}

void SCINotifyError(NSString *actionID, NSString *title, NSString *message) {
    [[SCINotificationCenter shared] notifyError:actionID title:title message:message];
}

void SCINotifyWarning(NSString *actionID, NSString *title, NSString *message) {
    SCINotify(actionID, title, message, @"exclamationmark.circle.fill", SCINotificationToneWarning);
}

SCINotificationHandle *SCINotifyProgress(NSString *actionID, NSString *title, void (^onCancel)(void)) {
    return [[SCINotificationCenter shared] beginProgressForAction:actionID title:title onCancel:onCancel];
}

SCINotificationHandle *SCINotifyLoading(NSString *actionID, NSString *title, void (^onCancel)(void)) {
    return [[SCINotificationCenter shared] beginLoadingForAction:actionID title:title onCancel:onCancel];
}
