// Reveal poll/quiz/slider results on story/reel stickers, force the
// legacy Quiz + Reveal stickers back into the composer tray, and bypass
// the Reveal sticker blur on the consumer side.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../StoriesAndMessages/StoryHelpers.h"
#import <objc/runtime.h>
#import <objc/message.h>

extern "C" __weak UIViewController *sciActiveStoryViewerVC;

// ============ Runtime helpers ============

static id sciCallMaybe(id obj, NSString *selName) {
    SEL sel = NSSelectorFromString(selName);
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    @try { return ((id(*)(id,SEL))objc_msgSend)(obj, sel); }
    @catch (__unused id e) { return nil; }
}

static NSArray *sciArrayIvar(id obj, const char *name) {
    if (!obj || !name) return nil;
    Class cls = [obj class];
    while (cls && cls != [NSObject class]) {
        Ivar iv = class_getInstanceVariable(cls, name);
        if (iv) {
            id v = object_getIvar(obj, iv);
            return [v isKindOfClass:[NSArray class]] ? (NSArray *)v : nil;
        }
        cls = class_getSuperclass(cls);
    }
    return nil;
}

// ============ Context detection (stories vs reels) ============

// Reels surface via IGSundialFeedViewController and also via contextual
// feeds (profile reels) that host Sundial-prefixed cells.
static BOOL sciIsInReelsContext(UIView *anchor) {
    Class reelCls = NSClassFromString(@"IGSundialFeedViewController");
    for (UIResponder *r = anchor; r; r = r.nextResponder) {
        if (reelCls && [r isKindOfClass:reelCls]) return YES;
        if ([NSStringFromClass([r class]) hasPrefix:@"IGSundial"]) return YES;
    }
    return NO;
}

static BOOL sciPrefShowPollCounts(UIView *anchor) {
    return [SCIUtils getBoolPref:
        sciIsInReelsContext(anchor)
            ? @"reels_show_poll_votes_count"
            : @"stories_show_poll_votes_count"];
}
static BOOL sciPrefShowQuizAnswer(UIView *anchor) {
    return [SCIUtils getBoolPref:
        sciIsInReelsContext(anchor)
            ? @"reels_show_quiz_answer"
            : @"stories_show_quiz_answer"];
}

// ============ Media lookup ============

static UIViewController *sciFindAnyStoryViewerVC(UIView *start) {
    Class target = NSClassFromString(@"IGStoryViewerViewController");
    if (!target) return nil;
    for (UIResponder *r = start; r; r = r.nextResponder) {
        if ([r isKindOfClass:target]) return (UIViewController *)r;
    }
    if (sciActiveStoryViewerVC) return sciActiveStoryViewerVC;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            NSMutableArray *stack = [NSMutableArray array];
            if (w.rootViewController) [stack addObject:w.rootViewController];
            while (stack.count) {
                UIViewController *cur = stack.lastObject;
                [stack removeLastObject];
                if ([cur isKindOfClass:target]) return cur;
                for (UIViewController *child in cur.childViewControllers) [stack addObject:child];
                if (cur.presentedViewController) [stack addObject:cur.presentedViewController];
            }
        }
    }
    return nil;
}

static IGMedia *sciCurrentStoryMedia(UIView *anchor) {
    UIViewController *vc = sciFindAnyStoryViewerVC(anchor);
    if (!vc) return nil;
    IGMedia *media = nil;
    @try {
        id vm = sciCall(vc, @selector(currentViewModel));
        id item = sciCall1(vc, @selector(currentStoryItemForViewModel:), vm);
        if ([item isKindOfClass:NSClassFromString(@"IGMedia")]) media = (IGMedia *)item;
        else media = sciExtractMediaFromItem(item);
    } @catch (__unused id e) {}
    return media;
}

// Walks the responder chain probing common getters for an IGMedia — covers
// reel cells where no story viewer VC is in the chain.
static IGMedia *sciFindMediaFromAnchor(UIView *anchor) {
    IGMedia *m = sciCurrentStoryMedia(anchor);
    if (m) return m;
    Class mediaCls = NSClassFromString(@"IGMedia");
    if (!mediaCls) return nil;
    NSArray *probes = @[@"media", @"post", @"feedItem", @"igMedia", @"storyItem",
                        @"item", @"model", @"backingModel", @"storyMedia",
                        @"currentMedia", @"currentMediaItem", @"currentStoryItem",
                        @"mediaModel", @"mediaItem"];
    for (UIResponder *r = anchor; r; r = r.nextResponder) {
        for (NSString *sel in probes) {
            id v = sciCallMaybe(r, sel);
            if ([v isKindOfClass:mediaCls]) return (IGMedia *)v;
            IGMedia *nested = sciExtractMediaFromItem(v);
            if (nested) return nested;
        }
    }
    return nil;
}

// View-local sticker models zero their tallies for unvoted viewers; the real
// counts live on IGMedia.{storyPolls,storyQuizs,storySliders} — match by pk.
static id sciAuthoritativeSticker(UIView *anchor, NSString *arrayKey, NSString *innerKey, id viewModel, NSString *idKey) {
    IGMedia *media = sciFindMediaFromAnchor(anchor);
    if (!media) return nil;
    NSArray *arr = sciCallMaybe(media, arrayKey);
    if (![arr isKindOfClass:[NSArray class]]) return nil;
    NSString *viewId = idKey ? [sciCallMaybe(viewModel, idKey) description] : nil;
    for (id entry in arr) {
        id sticker = sciCallMaybe(entry, innerKey);
        if (!sticker) continue;
        if (viewId.length) {
            NSString *stickerId = [sciCallMaybe(sticker, idKey) description];
            if ([stickerId isEqualToString:viewId]) return sticker;
        }
    }
    if (arr.count > 0) {
        id sticker = sciCallMaybe(arr[0], innerKey);
        if (sticker) return sticker;
    }
    return nil;
}

static NSInteger sciHighestTallyIndex(NSArray *tallies) {
    NSInteger best = -1, bestCount = 0;
    for (NSUInteger i = 0; i < tallies.count; i++) {
        NSInteger c = [(NSNumber *)sciCallMaybe(tallies[i], @"totalCount") integerValue];
        if (c > bestCount) { best = (NSInteger)i; bestCount = c; }
    }
    return best;
}

// ============ Editing/composer detection ============

static BOOL sciIsStickerEditing(UIView *v) {
    Class cls = [v class];
    while (cls && cls != [NSObject class]) {
        const char *names[] = { "_isEditing", "_editing" };
        for (size_t k = 0; k < sizeof(names)/sizeof(names[0]); k++) {
            Ivar iv = class_getInstanceVariable(cls, names[k]);
            if (!iv) continue;
            ptrdiff_t off = ivar_getOffset(iv);
            BOOL val = NO;
            memcpy(&val, (uint8_t *)(__bridge void *)v + off, sizeof(val));
            if (val) return YES;
        }
        cls = class_getSuperclass(cls);
    }
    NSArray *composers = @[@"IGStoryStickerTrayViewController",
                           @"IGStoryPostCaptureEditingViewController",
                           @"IGStoryMediaCompositionEditingViewController"];
    for (UIResponder *r = v; r; r = r.nextResponder) {
        NSString *cn = NSStringFromClass([r class]);
        for (NSString *c in composers) if ([cn isEqualToString:c]) return YES;
    }
    return NO;
}

// Keeps overlays in sync with the current item on story/reel nav.
static void sciForceRelayoutStickers(UIView *root) {
    if (!root) return;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
    Class pollV2 = NSClassFromString(@"IGPollStickerV2View");
    Class pollV1 = NSClassFromString(@"IGPollStickerView");
    Class slider = NSClassFromString(@"IGSliderStickerView");
    Class quiz = NSClassFromString(@"IGQuizStickerView");
    while (stack.count) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if ((pollV2 && [v isKindOfClass:pollV2]) ||
            (pollV1 && [v isKindOfClass:pollV1]) ||
            (slider && [v isKindOfClass:slider]) ||
            (quiz && [v isKindOfClass:quiz])) {
            [v setNeedsLayout];
            [v layoutIfNeeded];
        }
        for (UIView *sub in v.subviews) [stack addObject:sub];
    }
}

// Sticker views often lay out once with zero bounds / no cells; retries
// catch the settled state without relying on a second layoutSubviews.
static void sciScheduleRetries(UIView *view, SEL action) {
    __weak UIView *weak = view;
    NSArray *delays = @[@0.1, @0.3, @0.7];
    for (NSNumber *d in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *s = weak;
            if (s && s.window) ((void(*)(id,SEL))objc_msgSend)(s, action);
        });
    }
}

// ============ Overlay badges / highlight ============

static const char kSciPollBadgeKey = 0;
static const char kSciSliderBadgeKey = 0;
static const char kSciQuizHighlightKey = 0;

static UILabel *sciMakeBadge(void) {
    UILabel *b = [[UILabel alloc] init];
    b.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    b.textColor = [UIColor whiteColor];
    b.backgroundColor = [UIColor colorWithRed:0.0 green:0.45 blue:0.95 alpha:0.92];
    b.textAlignment = NSTextAlignmentCenter;
    b.layer.cornerRadius = 10;
    b.clipsToBounds = YES;
    b.userInteractionEnabled = NO;
    return b;
}

static void sciAttachPollCountBadge(UIView *optionView, NSInteger count, double total) {
    UILabel *badge = objc_getAssociatedObject(optionView, &kSciPollBadgeKey);
    if (!badge) {
        badge = sciMakeBadge();
        [optionView addSubview:badge];
        objc_setAssociatedObject(optionView, &kSciPollBadgeKey, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    badge.text = total > 0
        ? [NSString stringWithFormat:@" %ld · %.0f%% ", (long)count, 100.0 * (double)count / total]
        : [NSString stringWithFormat:@" %ld ", (long)count];
    [badge sizeToFit];
    CGSize sz = badge.bounds.size;
    sz.width += 10;
    sz.height = MAX(sz.height + 4, 22);
    CGRect b = optionView.bounds;
    badge.frame = CGRectMake(b.size.width - sz.width - 4, -sz.height * 0.35, sz.width, sz.height);
    badge.layer.zPosition = 1000;
    [optionView bringSubviewToFront:badge];
    optionView.clipsToBounds = NO;
}

static void sciAttachSliderBadge(UIView *sliderView, NSUInteger count, double avg) {
    UILabel *badge = objc_getAssociatedObject(sliderView, &kSciSliderBadgeKey);
    if (!badge) {
        badge = sciMakeBadge();
        [sliderView addSubview:badge];
        objc_setAssociatedObject(sliderView, &kSciSliderBadgeKey, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    badge.text = [NSString stringWithFormat:@"  %lu votes · avg %.0f%%  ",
                  (unsigned long)count, avg * 100.0];
    [badge sizeToFit];
    CGSize sz = badge.bounds.size;
    sz.height = MAX(sz.height, 18);
    CGRect b = sliderView.bounds;
    badge.frame = CGRectMake((b.size.width - sz.width) * 0.5, -sz.height - 4, sz.width, sz.height);
    [sliderView bringSubviewToFront:badge];
}

static void sciAttachQuizHighlight(UIView *optionView, CGFloat cornerRadius) {
    CAShapeLayer *hl = objc_getAssociatedObject(optionView, &kSciQuizHighlightKey);
    if (!hl) {
        hl = [CAShapeLayer layer];
        UIColor *green = [UIColor colorWithRed:0.24 green:0.76 blue:0.38 alpha:1.0];
        hl.fillColor = [green colorWithAlphaComponent:0.35].CGColor;
        hl.strokeColor = green.CGColor;
        hl.lineWidth = 2.0;
        hl.zPosition = 50;
        [optionView.layer addSublayer:hl];
        objc_setAssociatedObject(optionView, &kSciQuizHighlightKey, hl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGRect b = CGRectInset(optionView.bounds, 1.0, 1.0);
    hl.frame = optionView.bounds;
    hl.path = cornerRadius > 0
        ? [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:cornerRadius].CGPath
        : [UIBezierPath bezierPathWithRect:b].CGPath;
}

static void sciRemovePollCountBadge(UIView *v) {
    UILabel *b = objc_getAssociatedObject(v, &kSciPollBadgeKey);
    if (b) { [b removeFromSuperview]; objc_setAssociatedObject(v, &kSciPollBadgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}
static void sciRemoveSliderBadge(UIView *v) {
    UILabel *b = objc_getAssociatedObject(v, &kSciSliderBadgeKey);
    if (b) { [b removeFromSuperview]; objc_setAssociatedObject(v, &kSciSliderBadgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}
static void sciRemoveQuizHighlight(UIView *v) {
    CAShapeLayer *l = objc_getAssociatedObject(v, &kSciQuizHighlightKey);
    if (l) { [l removeFromSuperlayer]; objc_setAssociatedObject(v, &kSciQuizHighlightKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}

// ============ Poll reveal (V2 + legacy) ============

static void sciApplyPollReveal(UIView *pollView, NSArray *opts) {
    BOOL showCounts = sciPrefShowPollCounts(pollView);
    BOOL showWinner = sciPrefShowQuizAnswer(pollView);
    BOOL editing = sciIsStickerEditing(pollView);

    if ((!showCounts && !showWinner) || editing) {
        for (UIView *opt in opts) {
            if (![opt isKindOfClass:[UIView class]]) continue;
            sciRemovePollCountBadge(opt);
            sciRemoveQuizHighlight(opt);
        }
        return;
    }

    id viewModel = sciCallMaybe(pollView, @"igapiStickerModel") ?: sciCallMaybe(pollView, @"exportModel");
    id model = sciAuthoritativeSticker(pollView, @"storyPolls", @"pollSticker", viewModel, @"pollId") ?: viewModel;
    NSArray *tallies = sciCallMaybe(model, @"tallies");
    if (![tallies isKindOfClass:[NSArray class]]) tallies = nil;
    double total = [(NSNumber *)sciCallMaybe(model, @"totalVotes") doubleValue];

    NSNumber *correctAnswer = sciCallMaybe(model, @"correctAnswer");
    NSInteger winnerIdx = correctAnswer ? correctAnswer.integerValue : sciHighestTallyIndex(tallies ?: @[]);

    // V2 poll preallocates up to 4 option views; only render on real slots.
    NSUInteger realOptCount = tallies ? tallies.count : 0;
    for (NSUInteger i = 0; i < opts.count; i++) {
        UIView *opt = opts[i];
        if (![opt isKindOfClass:[UIView class]]) continue;
        if (i >= realOptCount) {
            sciRemovePollCountBadge(opt);
            sciRemoveQuizHighlight(opt);
            continue;
        }
        if (showCounts) {
            NSInteger c = [(NSNumber *)sciCallMaybe(tallies[i], @"totalCount") integerValue];
            sciAttachPollCountBadge(opt, c, total);
        } else {
            sciRemovePollCountBadge(opt);
        }
        if (showWinner && winnerIdx >= 0 && (NSInteger)i == winnerIdx) {
            sciAttachQuizHighlight(opt, 0.0);
        } else {
            sciRemoveQuizHighlight(opt);
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
//                                 STORIES                                   //
///////////////////////////////////////////////////////////////////////////////

%hook IGStoryViewerViewController

- (void)viewDidLayoutSubviews {
    %orig;
    sciForceRelayoutStickers(((UIViewController *)self).view);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        sciForceRelayoutStickers(((UIViewController *)self).view);
    });
}

%end

// IG ships the Quiz/Reveal classes + handlers but filters them out of the
// picker — re-inject the tray models when the pref is on.

static IGQuizStickerTrayModel *sciMakeQuizTrayModel(id neighborModel) {
    Class cls = NSClassFromString(@"IGQuizStickerTrayModel");
    if (!cls) return nil;
    id quiz = [[cls alloc] init];
    if (!quiz) return nil;
    @try {
        id section = sciCallMaybe(neighborModel, @"stickerSection");
        if (section && [quiz respondsToSelector:@selector(setStickerSection:)]) {
            [(IGQuizStickerTrayModel *)quiz setStickerSection:section];
        }
    } @catch (__unused id e) {}
    if ([quiz respondsToSelector:@selector(setPrompts:)]) {
        [(IGQuizStickerTrayModel *)quiz setPrompts:@[]];
    }
    return quiz;
}

static id sciMakeSecretTrayModel(id neighborModel) {
    Class cls = NSClassFromString(@"IGSecretStickerTrayModel");
    if (!cls) return nil;
    id m = [[cls alloc] init];
    if (!m) return nil;
    @try {
        id section = sciCallMaybe(neighborModel, @"stickerSection");
        if (section && [m respondsToSelector:@selector(setStickerSection:)]) {
            ((void(*)(id,SEL,id))objc_msgSend)(m, @selector(setStickerSection:), section);
        }
    } @catch (__unused id e) {}
    return m;
}

%hook IGStoryStickerDataSourceImpl

- (NSArray *)items {
    NSArray *orig = %orig;
    if (!orig || ![SCIUtils getBoolPref:@"force_enable_quiz_sticker"]) return orig;

    BOOL hasQuiz = NO, hasSecret = NO;
    for (id m in orig) {
        NSString *cn = NSStringFromClass([m class]);
        if ([cn rangeOfString:@"Quiz" options:NSCaseInsensitiveSearch].location != NSNotFound) hasQuiz = YES;
        if ([cn isEqualToString:@"IGSecretStickerTrayModel"]) hasSecret = YES;
    }

    NSMutableArray *mutated = nil;

    if (!hasQuiz) {
        // Slot next to poll/QnA so it lands in the interactive row.
        NSUInteger insertIdx = NSNotFound;
        id neighbor = nil;
        for (NSUInteger i = 0; i < orig.count; i++) {
            NSString *cn = NSStringFromClass([orig[i] class]);
            if ([cn isEqualToString:@"IGPollStickerV2TrayModel"] ||
                [cn isEqualToString:@"IGPollStickerTrayModel"]) {
                insertIdx = i + 1;
                neighbor = orig[i];
                break;
            }
        }
        if (insertIdx == NSNotFound) {
            for (NSUInteger i = 0; i < orig.count; i++) {
                if ([NSStringFromClass([orig[i] class]) isEqualToString:@"IGQuestionAnswerStickerModel"]) {
                    insertIdx = i + 1;
                    neighbor = orig[i];
                    break;
                }
            }
        }
        IGQuizStickerTrayModel *quiz = sciMakeQuizTrayModel(neighbor);
        if (quiz) {
            if (!mutated) mutated = [orig mutableCopy];
            if (insertIdx == NSNotFound) insertIdx = mutated.count;
            [mutated insertObject:quiz atIndex:insertIdx];
        }
    }

    if (!hasSecret) {
        NSArray *base = mutated ?: orig;
        NSUInteger insertIdx = NSNotFound;
        id neighbor = nil;
        for (NSUInteger i = 0; i < base.count; i++) {
            NSString *cn = NSStringFromClass([base[i] class]);
            if ([cn isEqualToString:@"IGQuizStickerTrayModel"] ||
                [cn isEqualToString:@"IGPollStickerV2TrayModel"] ||
                [cn isEqualToString:@"IGPollStickerTrayModel"] ||
                [cn isEqualToString:@"IGQuestionAnswerStickerModel"]) {
                insertIdx = i + 1;
                neighbor = base[i];
                break;
            }
        }
        id secret = sciMakeSecretTrayModel(neighbor);
        if (secret) {
            if (!mutated) mutated = [orig mutableCopy];
            if (insertIdx == NSNotFound) insertIdx = mutated.count;
            [mutated insertObject:secret atIndex:insertIdx];
        }
    }

    return mutated ?: orig;
}

%end

// IG checks these on IGGenAIRestyleExperimentHelper before listing the
// Reveal sticker in the tray and before consuming it.
%group SecretStickerGates

%hook IGGenAIRestyleExperimentHelper

+ (BOOL)isRevealStickerEnabledWithLauncherSet:(id)set {
    if ([SCIUtils getBoolPref:@"force_enable_quiz_sticker"]) return YES;
    return %orig;
}

+ (BOOL)isRevealStickerConsumptionEnabledWithLauncherSet:(id)set {
    if ([SCIUtils getBoolPref:@"force_enable_quiz_sticker"]) return YES;
    return %orig;
}

%end

%end

// Consumer-side bypass for the Reveal blur. IGStoryFullscreenOverlayView
// owns the blur state; the overlay-view hook is a fallback path.

%hook IGStoryFullscreenOverlayView

- (BOOL)isSecretStoryCurrentlyBlurred {
    if ([SCIUtils getBoolPref:@"bypass_reveal_sticker"]) return NO;
    return %orig;
}

- (void)showSecretStoryBlur:(BOOL)show animated:(BOOL)animated {
    if (show && [SCIUtils getBoolPref:@"bypass_reveal_sticker"]) {
        %orig(NO, animated);
        return;
    }
    %orig;
}

%end

%group SecretOverlayBypass

%hook IGSecretStickerOverlayView

- (void)layoutSubviews {
    %orig;
    if (![SCIUtils getBoolPref:@"bypass_reveal_sticker"]) return;
    if ([self respondsToSelector:@selector(setPreviewBlurEnabled:)]) {
        [self setPreviewBlurEnabled:NO];
    }
    ((UIView *)self).hidden = YES;
}

%end

%end

%ctor {
    %init;
    Class cls = NSClassFromString(@"_TtC25IGMagicModExperimentation30IGGenAIRestyleExperimentHelper");
    if (!cls) cls = NSClassFromString(@"IGGenAIRestyleExperimentHelper");
    if (cls) %init(SecretStickerGates, IGGenAIRestyleExperimentHelper = cls);

    Class overlay = NSClassFromString(@"_TtC15IGSecretSticker26IGSecretStickerOverlayView");
    if (!overlay) overlay = NSClassFromString(@"IGSecretStickerOverlayView");
    if (overlay) %init(SecretOverlayBypass, IGSecretStickerOverlayView = overlay);
}

///////////////////////////////////////////////////////////////////////////////
//                                  REELS                                    //
///////////////////////////////////////////////////////////////////////////////

%hook IGSundialFeedViewController

- (void)viewDidLayoutSubviews {
    %orig;
    sciForceRelayoutStickers(((UIViewController *)self).view);
}

%end

///////////////////////////////////////////////////////////////////////////////
//              STICKER VIEW HOOKS — shared by stories + reels               //
///////////////////////////////////////////////////////////////////////////////

// IGPollStickerV2View

%hook IGPollStickerV2View

%new
- (void)sci_applyPollReveal {
    sciApplyPollReveal(self, sciArrayIvar(self, "_optionViews") ?: @[]);
}

- (void)layoutSubviews {
    %orig;
    ((void(*)(id,SEL))objc_msgSend)(self, @selector(sci_applyPollReveal));
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) sciScheduleRetries(self, @selector(sci_applyPollReveal));
}

%end

// IGPollStickerView (legacy)

%hook IGPollStickerView

%new
- (void)sci_applyPollReveal {
    NSArray *opts = sciArrayIvar(self, "_optionViews")
                 ?: sciArrayIvar(self, "_voteOptionViews")
                 ?: sciArrayIvar(self, "_options");
    sciApplyPollReveal(self, opts ?: @[]);
}

- (void)layoutSubviews {
    %orig;
    ((void(*)(id,SEL))objc_msgSend)(self, @selector(sci_applyPollReveal));
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) sciScheduleRetries(self, @selector(sci_applyPollReveal));
}

%end

// IGSliderStickerView

%hook IGSliderStickerView

%new
- (void)sci_applySliderReveal {
    if (!sciPrefShowPollCounts(self) || sciIsStickerEditing(self)) {
        sciRemoveSliderBadge(self);
        return;
    }
    NSUInteger count = 0;
    double avg = 0.0;
    id model = sciCallMaybe(self, @"igapiStickerModel") ?: sciCallMaybe(self, @"exportModel");
    if (model) {
        count = [(NSNumber *)sciCallMaybe(model, @"sliderVoteCount") unsignedIntegerValue];
        avg = [(NSNumber *)sciCallMaybe(model, @"sliderVoteAverage") doubleValue];
    }
    if (count == 0 && avg == 0.0) {
        Ivar vc = class_getInstanceVariable([self class], "_voteCount");
        if (vc) memcpy(&count, (uint8_t *)(__bridge void *)self + ivar_getOffset(vc), sizeof(count));
        Ivar va = class_getInstanceVariable([self class], "_averageVote");
        if (va) avg = [(NSNumber *)object_getIvar(self, va) doubleValue];
    }
    sciAttachSliderBadge(self, count, avg);
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) sciScheduleRetries(self, @selector(sci_applySliderReveal));
}

- (void)layoutSubviews {
    %orig;
    ((void(*)(id,SEL))objc_msgSend)(self, @selector(sci_applySliderReveal));
}

// Refresh after the vote posts — count/average land on the ivars async.
- (void)emojiSliderDidEndSliding:(id)arg {
    %orig;
    sciScheduleRetries(self, @selector(sci_applySliderReveal));
}

%end

// IGQuizStickerView

%hook IGQuizStickerView

%new
- (void)sci_applyQuizReveal {
    BOOL showWinner = sciPrefShowQuizAnswer(self);
    BOOL editing = sciIsStickerEditing(self);

    UICollectionView *cv = nil;
    Ivar cvIvar = class_getInstanceVariable([self class], "_optionsCollectionView");
    if (cvIvar) {
        id v = object_getIvar(self, cvIvar);
        if ([v isKindOfClass:[UICollectionView class]]) cv = (UICollectionView *)v;
    }
    // Populate visibleCells before we walk them; IG also ships quiz
    // interaction off on the consumption path, so restore it.
    if (cv) { [cv setNeedsLayout]; [cv layoutIfNeeded]; cv.userInteractionEnabled = YES; }
    self.userInteractionEnabled = YES;
    NSArray *cells = cv ? cv.visibleCells : @[];

    if (!showWinner || editing) {
        for (UIView *cell in cells) sciRemoveQuizHighlight(cell);
        return;
    }

    id viewModel = sciCallMaybe(self, @"igapiStickerModel") ?: sciCallMaybe(self, @"exportModel");
    id model = sciAuthoritativeSticker(self, @"storyQuizs", @"quizSticker", viewModel, @"quizId") ?: viewModel;
    NSNumber *correct = sciCallMaybe(model, @"correctAnswer");
    NSInteger winnerIdx = correct ? correct.integerValue : -1;

    // Quiz cell corner radius lives on a sublayer; hardcode to match.
    for (UICollectionViewCell *cell in cells) {
        if (![cell isKindOfClass:[UICollectionViewCell class]]) continue;
        NSIndexPath *ip = cv ? [cv indexPathForCell:cell] : nil;
        NSInteger i = ip ? ip.row : -1;
        if (i < 0) continue;
        if (winnerIdx >= 0 && i == winnerIdx) {
            sciAttachQuizHighlight(cell, 18.0);
        } else {
            sciRemoveQuizHighlight(cell);
        }
    }
}

- (void)layoutSubviews {
    %orig;
    ((void(*)(id,SEL))objc_msgSend)(self, @selector(sci_applyQuizReveal));
    sciScheduleRetries(self, @selector(sci_applyQuizReveal));
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) sciScheduleRetries(self, @selector(sci_applyQuizReveal));
}

%end
