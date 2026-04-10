// Download + mark seen buttons on story/DM visual message overlay
#import "StoryHelpers.h"
#import "SCIExcludedThreads.h"
#import "SCIExcludedStoryUsers.h"

extern "C" BOOL sciSeenBypassActive;
extern "C" BOOL sciAdvanceBypassActive;
extern "C" NSMutableSet *sciAllowedSeenPKs;
extern "C" void sciAllowSeenForPK(id);
extern "C" BOOL sciIsCurrentStoryOwnerExcluded(void);
extern "C" NSDictionary *sciCurrentStoryOwnerInfo(void);
extern "C" NSDictionary *sciOwnerInfoForView(UIView *view);
extern "C" BOOL sciStorySeenToggleEnabled;
extern "C" void sciRefreshAllVisibleOverlays(UIViewController *storyVC);
extern "C" void sciTriggerStoryMarkSeen(UIViewController *storyVC);
extern "C" __weak UIViewController *sciActiveStoryViewerVC;
extern "C" void sciToggleStoryAudio(void);
extern "C" BOOL sciIsStoryAudioEnabled(void);
extern "C" void sciInitStoryAudioState(void);
extern "C" void sciResetStoryAudioState(void);

static SCIDownloadDelegate *sciStoryVideoDl = nil;
static SCIDownloadDelegate *sciStoryImageDl = nil;

static void sciInitStoryDownloaders() {
    NSString *method = [SCIUtils getStringPref:@"dw_save_action"];
    DownloadAction action = [method isEqualToString:@"photos"] ? saveToPhotos : share;
    DownloadAction imgAction = [method isEqualToString:@"photos"] ? saveToPhotos : quickLook;
    sciStoryVideoDl = [[SCIDownloadDelegate alloc] initWithAction:action showProgress:YES];
    sciStoryImageDl = [[SCIDownloadDelegate alloc] initWithAction:imgAction showProgress:NO];
}

static void sciDownloadMedia(IGMedia *media) {
    sciInitStoryDownloaders();
    NSURL *videoUrl = [SCIUtils getVideoUrlForMedia:media];
    if (videoUrl) {
        [sciStoryVideoDl downloadFileWithURL:videoUrl fileExtension:[[videoUrl lastPathComponent] pathExtension] hudLabel:nil];
        return;
    }
    NSURL *photoUrl = [SCIUtils getPhotoUrlForMedia:media];
    if (photoUrl) {
        [sciStoryImageDl downloadFileWithURL:photoUrl fileExtension:[[photoUrl lastPathComponent] pathExtension] hudLabel:nil];
        return;
    }
    [SCIUtils showErrorHUDWithDescription:@"Could not extract URL"];
}

static void sciDownloadWithConfirm(void(^block)(void)) {
    if ([SCIUtils getBoolPref:@"dw_confirm"]) {
        [SCIUtils showConfirmation:block title:@"Download?"];
    } else {
        block();
    }
}

static void sciDownloadDMVisualMessage(UIViewController *dmVC) {
    Ivar dsIvar = class_getInstanceVariable([dmVC class], "_dataSource");
    id ds = dsIvar ? object_getIvar(dmVC, dsIvar) : nil;
    if (!ds) return;
    Ivar msgIvar = class_getInstanceVariable([ds class], "_currentMessage");
    id msg = msgIvar ? object_getIvar(ds, msgIvar) : nil;
    if (!msg) return;

    id rawVideo = sciCall(msg, @selector(rawVideo));
    if (rawVideo) {
        NSURL *url = [SCIUtils getVideoUrl:rawVideo];
        if (url) {
            sciInitStoryDownloaders();
            sciDownloadWithConfirm(^{ [sciStoryVideoDl downloadFileWithURL:url fileExtension:[[url lastPathComponent] pathExtension] hudLabel:nil]; });
            return;
        }
    }

    id rawPhoto = sciCall(msg, @selector(rawPhoto));
    if (rawPhoto) {
        NSURL *url = [SCIUtils getPhotoUrl:rawPhoto];
        if (url) {
            sciInitStoryDownloaders();
            sciDownloadWithConfirm(^{ [sciStoryImageDl downloadFileWithURL:url fileExtension:[[url lastPathComponent] pathExtension] hudLabel:nil]; });
            return;
        }
    }

    id imgSpec = sciCall(msg, NSSelectorFromString(@"imageSpecifier"));
    if (imgSpec) {
        NSURL *url = sciCall(imgSpec, @selector(url));
        if (url) {
            sciInitStoryDownloaders();
            sciDownloadWithConfirm(^{ [sciStoryImageDl downloadFileWithURL:url fileExtension:[[url lastPathComponent] pathExtension] hudLabel:nil]; });
            return;
        }
    }

    Ivar vmiIvar = class_getInstanceVariable([msg class], "_visualMediaInfo");
    id vmi = vmiIvar ? object_getIvar(msg, vmiIvar) : nil;
    if (vmi) {
        Ivar mediaIvar = class_getInstanceVariable([vmi class], "_media");
        id mediaObj = mediaIvar ? object_getIvar(vmi, mediaIvar) : nil;
        if (mediaObj) {
            IGMedia *media = sciExtractMediaFromItem(mediaObj);
            if (!media && [mediaObj isKindOfClass:NSClassFromString(@"IGMedia")]) media = (IGMedia *)mediaObj;
            if (media) { sciDownloadWithConfirm(^{ sciDownloadMedia(media); }); return; }
        }
    }

    [SCIUtils showErrorHUDWithDescription:@"Could not find media"];
}

%hook IGStoryFullscreenOverlayView

// ============ Button injection ============

- (void)didMoveToSuperview {
    %orig;
    if (!self.superview) return;

    // Download button
    if ([SCIUtils getBoolPref:@"dw_story"] && ![self viewWithTag:1340]) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 1340;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        [btn setImage:[UIImage systemImageNamed:@"arrow.down" withConfiguration:cfg] forState:UIControlStateNormal];
        btn.tintColor = [UIColor whiteColor];
        btn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        btn.layer.cornerRadius = 18;
        btn.clipsToBounds = YES;
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn addTarget:self action:@selector(sciDownloadTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        [NSLayoutConstraint activateConstraints:@[
            [btn.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-100],
            [btn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [btn.widthAnchor constraintEqualToConstant:36],
            [btn.heightAnchor constraintEqualToConstant:36]
        ]];
    }

    // Audio toggle button (left side, small)
    sciInitStoryAudioState();
    if ([SCIUtils getBoolPref:@"story_audio_toggle"] && ![self viewWithTag:1341]) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 1341;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
        NSString *icon = sciIsStoryAudioEnabled() ? @"speaker.wave.2" : @"speaker.slash";
        [btn setImage:[UIImage systemImageNamed:icon withConfiguration:cfg] forState:UIControlStateNormal];
        btn.tintColor = [UIColor whiteColor];
        btn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        btn.layer.cornerRadius = 14;
        btn.clipsToBounds = YES;
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn addTarget:self action:@selector(sciAudioToggleTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        [NSLayoutConstraint activateConstraints:@[
            [btn.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-100],
            [btn.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [btn.widthAnchor constraintEqualToConstant:28],
            [btn.heightAnchor constraintEqualToConstant:28]
        ]];
    }

    // Seen button — deferred so the responder chain is wired up
    __weak UIView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *s = weakSelf;
        if (s && s.superview) ((void(*)(id, SEL))objc_msgSend)(s, @selector(sciRefreshSeenButton));
    });
}

// ============ Seen button lifecycle ============

// Refresh the audio toggle icon (tag 1341) to match current state.
%new - (void)sciRefreshAudioButton {
    UIButton *btn = (UIButton *)[self viewWithTag:1341];
    if (!btn) return;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    NSString *icon = sciIsStoryAudioEnabled() ? @"speaker.wave.2" : @"speaker.slash";
    [btn setImage:[UIImage systemImageNamed:icon withConfiguration:cfg] forState:UIControlStateNormal];
}

// Rebuilds the eye button (tag 1339) based on current owner + prefs. Idempotent.
%new - (void)sciRefreshSeenButton {
    BOOL seenBlockingOn = [SCIUtils getBoolPref:@"no_seen_receipt"];
    BOOL storyBlockSelected = [SCIExcludedStoryUsers isBlockSelectedMode];
    // In block_selected mode, show the eye for list management even if global toggle is off
    if (!seenBlockingOn && !storyBlockSelected) return;
    // Skip for DM visual messages inside an excluded thread
    NSString *activeTid = [SCIExcludedThreads activeThreadId];
    if (activeTid && [SCIExcludedThreads isInList:activeTid] && ![SCIExcludedThreads isBlockSelectedMode]) return;

    NSDictionary *ownerInfo = sciOwnerInfoForView(self);
    NSString *ownerPK = ownerInfo[@"pk"] ?: @"";
    BOOL ownerInList = ownerPK.length && [SCIExcludedStoryUsers isInList:ownerPK];
    // block_all + in list: show remove icon (excluded user, behaves normally)
    // block_selected + in list: show normal eye (blocked user, needs mark-seen)
    // block_selected + not in list: show add icon
    BOOL showExcludeIcon = ownerInList && !storyBlockSelected;
    BOOL showAddIcon = storyBlockSelected && !ownerInList;
    BOOL listBtnPref = [SCIUtils getBoolPref:@"story_excluded_show_unexclude_eye"];
    BOOL hideForListedOwner = (showExcludeIcon || showAddIcon) && !listBtnPref;
    BOOL toggleMode = [[SCIUtils getStringPref:@"story_seen_mode"] isEqualToString:@"toggle"];

    NSString *symName;
    UIColor *tint;
    if (showExcludeIcon) {
        // block_all + in list: remove-from-exclude icon
        symName = @"eye.slash.fill"; tint = SCIUtils.SCIColor_Primary;
    } else if (storyBlockSelected && !ownerInList) {
        // block_selected + not in list: add-to-block icon
        symName = @"eye.slash"; tint = [UIColor whiteColor];
    } else if (toggleMode) {
        symName = sciStorySeenToggleEnabled ? @"eye.fill" : @"eye";
        tint = sciStorySeenToggleEnabled ? SCIUtils.SCIColor_Primary : [UIColor whiteColor];
    } else {
        symName = @"eye"; tint = [UIColor whiteColor];
    }

    UIButton *existing = (UIButton *)[self viewWithTag:1339];

    if (hideForListedOwner) {
        [existing removeFromSuperview];
        return;
    }

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];

    if (existing) {
        [existing setImage:[UIImage systemImageNamed:symName withConfiguration:cfg] forState:UIControlStateNormal];
        existing.tintColor = tint;
        return;
    }

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = 1339;
    [btn setImage:[UIImage systemImageNamed:symName withConfiguration:cfg] forState:UIControlStateNormal];
    btn.tintColor = tint;
    btn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    btn.layer.cornerRadius = 18;
    btn.clipsToBounds = YES;
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(sciSeenButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(sciSeenButtonLongPressed:)];
    lp.minimumPressDuration = 0.4;
    [btn addGestureRecognizer:lp];
    [self addSubview:btn];
    UIView *anchor = [self viewWithTag:1340];
    if (anchor) {
        [NSLayoutConstraint activateConstraints:@[
            [btn.centerYAnchor constraintEqualToAnchor:anchor.centerYAnchor],
            [btn.trailingAnchor constraintEqualToAnchor:anchor.leadingAnchor constant:-10],
            [btn.widthAnchor constraintEqualToConstant:36],
            [btn.heightAnchor constraintEqualToConstant:36]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [btn.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-100],
            [btn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [btn.widthAnchor constraintEqualToConstant:36],
            [btn.heightAnchor constraintEqualToConstant:36]
        ]];
    }
}

// Refresh when story owner changes or audio state changes
- (void)layoutSubviews {
    %orig;
    static char kLastPKKey;
    static char kLastExclKey;
    static char kLastAudioKey;

    // Audio button: check if state changed
    UIButton *audioBtn = (UIButton *)[self viewWithTag:1341];
    if (audioBtn) {
        BOOL audioOn = sciIsStoryAudioEnabled();
        NSNumber *prevAudio = objc_getAssociatedObject(self, &kLastAudioKey);
        if (!prevAudio || [prevAudio boolValue] != audioOn) {
            objc_setAssociatedObject(self, &kLastAudioKey, @(audioOn), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ((void(*)(id, SEL))objc_msgSend)(self, @selector(sciRefreshAudioButton));
        }
    }

    // Seen button: check if owner/exclusion changed
    if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return;
    NSDictionary *info = sciOwnerInfoForView(self);
    NSString *pk = info[@"pk"] ?: @"";
    BOOL excluded = pk.length && [SCIExcludedStoryUsers isUserPKExcluded:pk];
    NSString *prev = objc_getAssociatedObject(self, &kLastPKKey);
    NSNumber *prevExcl = objc_getAssociatedObject(self, &kLastExclKey);
    BOOL changed = ![pk isEqualToString:prev ?: @""] || (prevExcl && [prevExcl boolValue] != excluded);
    if (!changed) return;
    objc_setAssociatedObject(self, &kLastPKKey, pk, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &kLastExclKey, @(excluded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void(*)(id, SEL))objc_msgSend)(self, @selector(sciRefreshSeenButton));
}

// ============ Audio toggle handler ============

%new - (void)sciAudioToggleTapped:(UIButton *)sender {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
    sciToggleStoryAudio();
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    NSString *icon = sciIsStoryAudioEnabled() ? @"speaker.wave.2" : @"speaker.slash";
    [sender setImage:[UIImage systemImageNamed:icon withConfiguration:cfg] forState:UIControlStateNormal];
}

// ============ Download handler ============

%new - (void)sciDownloadTapped:(UIButton *)sender {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    [UIView animateWithDuration:0.1 animations:^{ sender.transform = CGAffineTransformMakeScale(0.8, 0.8); }
                     completion:^(BOOL f) { [UIView animateWithDuration:0.1 animations:^{ sender.transform = CGAffineTransformIdentity; }]; }];
    @try {
        id item = sciGetCurrentStoryItem(self);
        IGMedia *media = sciExtractMediaFromItem(item);
        if (media) {
            sciDownloadWithConfirm(^{ sciDownloadMedia(media); });
            return;
        }

        UIViewController *dmVC = sciFindVC(self, @"IGDirectVisualMessageViewerController");
        if (dmVC) {
            sciDownloadDMVisualMessage(dmVC);
            return;
        }

        [SCIUtils showErrorHUDWithDescription:@"Could not find media"];
    } @catch (NSException *e) {
        [SCIUtils showErrorHUDWithDescription:[NSString stringWithFormat:@"Error: %@", e.reason]];
    }
}

// ============ Seen button tap ============

%new - (void)sciSeenButtonTapped:(UIButton *)sender {
    NSDictionary *ownerInfo = sciOwnerInfoForView(self);
    NSString *ownerPK = ownerInfo[@"pk"];
    BOOL inList = ownerPK && [SCIExcludedStoryUsers isInList:ownerPK];
    BOOL bs = [SCIExcludedStoryUsers isBlockSelectedMode];

    // Block selected + not in list: tap to ADD to block list (with confirmation)
    if (bs && !inList && ownerPK) {
        UIViewController *host = [SCIUtils nearestViewControllerForView:self];
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Add to block list?"
                             message:[NSString stringWithFormat:@"Story seen receipts will be blocked for @%@.", ownerInfo[@"username"] ?: @""]
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
            [SCIExcludedStoryUsers addOrUpdateEntry:@{
                @"pk": ownerPK,
                @"username": ownerInfo[@"username"] ?: @"",
                @"fullName": ownerInfo[@"fullName"] ?: @""
            }];
            [SCIUtils showToastForDuration:2.0 title:@"Added to block list"];
            sciRefreshAllVisibleOverlays(sciActiveStoryViewerVC);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [host presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Block selected + in list: blocked story, tap = mark seen (long-press to remove)
    if (bs && inList) {
        ((void(*)(id, SEL, id))objc_msgSend)(self, @selector(sciMarkSeenTapped:), sender);
        return;
    }

    // Block all + in list: tap to remove from exclude list
    if (inList) {
        UIViewController *host = [SCIUtils nearestViewControllerForView:self];
        NSString *alertTitle = bs ? @"Remove from block list?" : @"Un-exclude story seen?";
        NSString *alertMsg = bs ? [NSString stringWithFormat:@"@%@ will no longer have seen receipts blocked.", ownerInfo[@"username"] ?: @""]
                                : [NSString stringWithFormat:@"@%@ will resume normal story-seen blocking.", ownerInfo[@"username"] ?: @""];
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:alertTitle message:alertMsg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:bs ? @"Unblock" : @"Un-exclude" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
            [SCIExcludedStoryUsers removePK:ownerPK];
            [SCIUtils showToastForDuration:2.0 title:bs ? @"Unblocked" : @"Un-excluded"];
            if (bs) sciTriggerStoryMarkSeen(sciActiveStoryViewerVC);
            sciRefreshAllVisibleOverlays(sciActiveStoryViewerVC);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [host presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Toggle mode
    if ([[SCIUtils getStringPref:@"story_seen_mode"] isEqualToString:@"toggle"]) {
        sciStorySeenToggleEnabled = !sciStorySeenToggleEnabled;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        [sender setImage:[UIImage systemImageNamed:(sciStorySeenToggleEnabled ? @"eye.fill" : @"eye") withConfiguration:cfg] forState:UIControlStateNormal];
        sender.tintColor = sciStorySeenToggleEnabled ? SCIUtils.SCIColor_Primary : [UIColor whiteColor];
        [SCIUtils showToastForDuration:2.0 title:sciStorySeenToggleEnabled ? @"Story read receipts enabled" : @"Story read receipts disabled"];
        return;
    }

    // Button mode: mark seen once
    ((void(*)(id, SEL, id))objc_msgSend)(self, @selector(sciMarkSeenTapped:), sender);
}

// ============ Seen button long-press menu ============

%new - (void)sciSeenButtonLongPressed:(UILongPressGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    UIView *btn = gr.view;
    UIViewController *host = [SCIUtils nearestViewControllerForView:self];
    if (!host) return;
    UIWindow *capturedWin = btn.window ?: self.window;
    if (!capturedWin) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) { if (w.isKeyWindow) { capturedWin = w; break; } }
    }
    NSDictionary *ownerInfo = sciOwnerInfoForView(self);
    NSString *pk = ownerInfo[@"pk"];
    NSString *username = ownerInfo[@"username"] ?: @"";
    NSString *fullName = ownerInfo[@"fullName"] ?: @"";
    BOOL inList = pk && [SCIExcludedStoryUsers isInList:pk];
    BOOL blockSelected = [SCIExcludedStoryUsers isBlockSelectedMode];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Mark seen" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        ((void(*)(id, SEL, id))objc_msgSend)(self, @selector(sciMarkSeenTapped:), btn);
    }]];
    if (pk) {
        NSString *addLabel = blockSelected ? @"Add to block list" : @"Exclude story seen";
        NSString *removeLabel = blockSelected ? @"Remove from block list" : @"Un-exclude story seen";
        NSString *t = inList ? removeLabel : addLabel;
        [sheet addAction:[UIAlertAction actionWithTitle:t style:inList ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
            if (inList) {
                [SCIExcludedStoryUsers removePK:pk];
                [SCIUtils showToastForDuration:2.0 title:blockSelected ? @"Unblocked" : @"Un-excluded"];
                if (blockSelected) sciTriggerStoryMarkSeen(sciActiveStoryViewerVC);
            } else {
                [SCIExcludedStoryUsers addOrUpdateEntry:@{ @"pk": pk, @"username": username, @"fullName": fullName }];
                [SCIUtils showToastForDuration:2.0 title:blockSelected ? @"Blocked" : @"Excluded"];
                if (!blockSelected) sciTriggerStoryMarkSeen(sciActiveStoryViewerVC);
            }
            sciRefreshAllVisibleOverlays(sciActiveStoryViewerVC);
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Stories settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [SCIUtils showSettingsVC:capturedWin atTopLevelEntry:@"Stories"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = btn;
    sheet.popoverPresentationController.sourceRect = btn.bounds;
    [host presentViewController:sheet animated:YES completion:nil];
}

// ============ Mark seen handler ============

%new - (void)sciMarkSeenTapped:(UIButton *)sender {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    if (sender) {
        [UIView animateWithDuration:0.1 animations:^{ sender.transform = CGAffineTransformMakeScale(0.8, 0.8); sender.alpha = 0.6; }
                         completion:^(BOOL f) { [UIView animateWithDuration:0.15 animations:^{ sender.transform = CGAffineTransformIdentity; sender.alpha = 1.0; }]; }];
    }

    @try {
        // Story path
        UIViewController *storyVC = sciFindVC(self, @"IGStoryViewerViewController");
        if (storyVC) {
            id sectionCtrl = sciFindSectionController(storyVC);
            id storyItem = sectionCtrl ? sciCall(sectionCtrl, NSSelectorFromString(@"currentStoryItem")) : nil;
            if (!storyItem) storyItem = sciGetCurrentStoryItem(self);
            IGMedia *media = (storyItem && [storyItem isKindOfClass:NSClassFromString(@"IGMedia")]) ? storyItem : sciExtractMediaFromItem(storyItem);

            if (!media) { [SCIUtils showErrorHUDWithDescription:@"Could not find story media"]; return; }

            sciAllowSeenForPK(media);
            sciSeenBypassActive = YES;

            SEL delegateSel = @selector(fullscreenSectionController:didMarkItemAsSeen:);
            if ([storyVC respondsToSelector:delegateSel]) {
                typedef void (*Func)(id, SEL, id, id);
                ((Func)objc_msgSend)(storyVC, delegateSel, sectionCtrl, media);
            }
            if (sectionCtrl) {
                SEL markSel = NSSelectorFromString(@"markItemAsSeen:");
                if ([sectionCtrl respondsToSelector:markSel])
                    ((SCIMsgSend1)objc_msgSend)(sectionCtrl, markSel, media);
            }
            id seenManager = sciCall(storyVC, @selector(viewingSessionSeenStateManager));
            id vm = sciCall(storyVC, @selector(currentViewModel));
            if (seenManager && vm) {
                SEL setSel = NSSelectorFromString(@"setSeenMediaId:forReelPK:");
                if ([seenManager respondsToSelector:setSel]) {
                    id mediaPK = sciCall(media, @selector(pk));
                    id reelPK = sciCall(vm, NSSelectorFromString(@"reelPK"));
                    if (!reelPK) reelPK = sciCall(vm, @selector(pk));
                    if (mediaPK && reelPK) {
                        typedef void (*SetFunc)(id, SEL, id, id);
                        ((SetFunc)objc_msgSend)(seenManager, setSel, mediaPK, reelPK);
                    }
                }
            }
            sciSeenBypassActive = NO;
            [SCIUtils showToastForDuration:2.0 title:@"Marked as seen" subtitle:@"Will sync when leaving stories"];

            // Advance to next story if enabled (skip when triggered programmatically via exclude)
            if (sender && [SCIUtils getBoolPref:@"advance_on_mark_seen"] && sectionCtrl) {
                __block id secCtrl = sectionCtrl;
                __weak __typeof(self) weakSelf = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    sciAdvanceBypassActive = YES;
                    SEL advSel = NSSelectorFromString(@"advanceToNextItemWithNavigationAction:");
                    if ([secCtrl respondsToSelector:advSel])
                        ((void(*)(id, SEL, NSInteger))objc_msgSend)(secCtrl, advSel, 1);

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong __typeof(weakSelf) strongSelf = weakSelf;
                        UIViewController *vc2 = strongSelf ? sciFindVC(strongSelf, @"IGStoryViewerViewController") : nil;
                        id sc2 = vc2 ? sciFindSectionController(vc2) : nil;
                        if (sc2) {
                            SEL resumeSel = NSSelectorFromString(@"tryResumePlaybackWithReason:");
                            if ([sc2 respondsToSelector:resumeSel])
                                ((void(*)(id, SEL, NSInteger))objc_msgSend)(sc2, resumeSel, 0);
                        }
                        sciAdvanceBypassActive = NO;
                    });
                });
            }
            return;
        }

        // DM visual message path
        UIViewController *dmVC = sciFindVC(self, @"IGDirectVisualMessageViewerController");
        if (dmVC) {
            extern BOOL dmVisualMsgsViewedButtonEnabled;
            BOOL wasEnabled = dmVisualMsgsViewedButtonEnabled;
            dmVisualMsgsViewedButtonEnabled = YES;

            Ivar dsIvar = class_getInstanceVariable([dmVC class], "_dataSource");
            id ds = dsIvar ? object_getIvar(dmVC, dsIvar) : nil;
            Ivar msgIvar = ds ? class_getInstanceVariable([ds class], "_currentMessage") : nil;
            id msg = msgIvar ? object_getIvar(ds, msgIvar) : nil;
            Ivar erIvar = class_getInstanceVariable([dmVC class], "_eventResponders");
            NSArray *responders = erIvar ? object_getIvar(dmVC, erIvar) : nil;

            if (responders && msg) {
                for (id resp in responders) {
                    SEL beginSel = @selector(visualMessageViewerController:didBeginPlaybackForVisualMessage:atIndex:);
                    if ([resp respondsToSelector:beginSel]) {
                        typedef void (*Fn)(id, SEL, id, id, NSInteger);
                        ((Fn)objc_msgSend)(resp, beginSel, dmVC, msg, 0);
                    }
                    SEL endSel = @selector(visualMessageViewerController:didEndPlaybackForVisualMessage:atIndex:mediaCurrentTime:forNavType:);
                    if ([resp respondsToSelector:endSel]) {
                        typedef void (*Fn)(id, SEL, id, id, NSInteger, CGFloat, NSInteger);
                        ((Fn)objc_msgSend)(resp, endSel, dmVC, msg, 0, 0.0, 0);
                    }
                }
            }

            SEL dismissSel = NSSelectorFromString(@"_didTapHeaderViewDismissButton:");
            if ([dmVC respondsToSelector:dismissSel])
                ((void(*)(id,SEL,id))objc_msgSend)(dmVC, dismissSel, nil);

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                dmVisualMsgsViewedButtonEnabled = wasEnabled;
            });

            [SCIUtils showToastForDuration:1.5 title:@"Marked as viewed"];
            return;
        }

        [SCIUtils showErrorHUDWithDescription:@"VC not found"];
    } @catch (NSException *e) {
        [SCIUtils showErrorHUDWithDescription:[NSString stringWithFormat:@"Error: %@", e.reason]];
    }
}

%end

// ============ Chrome alpha sync ============

static void sciSyncStoryButtonsAlpha(UIView *self_, CGFloat alpha) {
    Class overlayCls = NSClassFromString(@"IGStoryFullscreenOverlayView");
    if (!overlayCls) return;
    UIView *cur = self_;
    while (cur) {
        for (UIView *sib in cur.superview.subviews) {
            if (![sib isKindOfClass:overlayCls]) continue;
            UIView *seen  = [sib viewWithTag:1339];
            UIView *dl    = [sib viewWithTag:1340];
            UIView *audio = [sib viewWithTag:1341];
            if (seen)  seen.alpha  = alpha;
            if (dl)    dl.alpha    = alpha;
            if (audio) audio.alpha = alpha;
            return;
        }
        cur = cur.superview;
    }
}

%hook IGStoryFullscreenHeaderView
- (void)setAlpha:(CGFloat)alpha {
    %orig;
    sciSyncStoryButtonsAlpha((UIView *)self, alpha);
}
%end
