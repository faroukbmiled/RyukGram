#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// Bypass flag: when YES, all hooks let calls through (for manual mark as seen)
static BOOL sciSeenBypassActive = NO;

static BOOL sciShouldBlockSeen() {
    if (sciSeenBypassActive) return NO;
    return [SCIUtils getBoolPref:@"no_seen_receipt"];
}

// Block story seen receipts by intercepting all known upload/send paths
%hook IGStorySeenStateUploader
- (id)initWithUserSessionPK:(id)arg1 networker:(id)arg2 {
    if (sciShouldBlockSeen()) {
        NSLog(@"[SCInsta] Blocked story seen uploader init");
        return nil;
    }
    return %orig;
}
- (void)uploadSeenStateWithMedia:(id)arg1 {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)uploadSeenState {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)_uploadSeenState:(id)arg1 {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)sendSeenReceipt:(id)arg1 {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (id)networker {
    if (sciShouldBlockSeen()) return nil;
    return %orig;
}
%end

// Block seen tracking on fullscreen section controller
%hook IGStoryFullscreenSectionController
- (void)markItemAsSeen:(id)arg1 {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)_markItemAsSeen:(id)arg1 {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)storySeenStateDidChange:(id)arg1 {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)sendSeenRequestForCurrentItem {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)markCurrentItemAsSeen {
    if (sciShouldBlockSeen()) return;
    %orig;
}
%end

// Block seen on viewer controller
%hook IGStoryViewerViewController
- (void)markAsSeen {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)markStoryAsSeen:(id)arg1 {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)_markCurrentStoryAsSeen {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)markCurrentMediaAsSeen {
    if (sciShouldBlockSeen()) return;
    %orig;
}
%end

// Block local visual seen state updates on the story tray
// This prevents the colored ring from turning grey after viewing
%hook IGStoryTrayViewModel
- (void)markAsSeen {
    if (sciShouldBlockSeen()) return;
    %orig;
}
- (void)setHasUnseenMedia:(BOOL)arg1 {
    if (sciShouldBlockSeen()) {
        // Always keep as unseen visually
        %orig(YES);
        return;
    }
    %orig;
}
- (BOOL)hasUnseenMedia {
    if (sciShouldBlockSeen()) return YES;
    return %orig;
}
- (void)setIsSeen:(BOOL)arg1 {
    if (sciShouldBlockSeen()) {
        %orig(NO);
        return;
    }
    %orig;
}
- (BOOL)isSeen {
    if (sciShouldBlockSeen()) return NO;
    return %orig;
}
%end

// Also try to block on the story item model level
%hook IGStoryItem
- (void)setHasSeen:(BOOL)arg1 {
    if (sciShouldBlockSeen()) {
        %orig(NO);
        return;
    }
    %orig;
}
- (BOOL)hasSeen {
    if (sciShouldBlockSeen()) return NO;
    return %orig;
}
%end

// Manual "mark as seen" button on story overlay
%hook IGStoryFullscreenOverlayView
- (void)didMoveToSuperview {
    %orig;

    if (!sciShouldBlockSeen()) return;
    if ([self viewWithTag:1339]) return;

    UIButton *seenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    seenBtn.tag = 1339;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    UIImage *icon = [UIImage systemImageNamed:@"eye" withConfiguration:config];
    [seenBtn setImage:icon forState:UIControlStateNormal];
    [seenBtn setTitle:@" Mark seen" forState:UIControlStateNormal];
    [seenBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    seenBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    seenBtn.tintColor = [UIColor whiteColor];
    seenBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    seenBtn.layer.cornerRadius = 14;
    seenBtn.clipsToBounds = YES;
    seenBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 10, 6, 12);

    seenBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [seenBtn addTarget:self action:@selector(sciMarkSeenTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:seenBtn];

    // Bottom right, moved up to avoid overlapping existing buttons
    [NSLayoutConstraint activateConstraints:@[
        [seenBtn.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-110],
        [seenBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [seenBtn.heightAnchor constraintEqualToConstant:28]
    ]];
}

%new - (void)sciMarkSeenTapped:(UIButton *)sender {
    // Haptic feedback
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    // Visual feedback
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.85, 0.85);
        sender.alpha = 0.6;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            sender.transform = CGAffineTransformIdentity;
            sender.alpha = 1.0;
        }];
    }];

    // Enable bypass so all our hooks let the calls through
    sciSeenBypassActive = YES;

    BOOL didMark = NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // Try all view controllers in responder chain
    UIResponder *responder = self;
    while (responder) {
        // IGStoryViewerViewController
        if ([responder isKindOfClass:NSClassFromString(@"IGStoryViewerViewController")]) {
            SEL selectors[] = {
                @selector(markAsSeen), @selector(markStoryAsSeen:),
                @selector(_markCurrentStoryAsSeen), @selector(markCurrentMediaAsSeen)
            };
            for (int i = 0; i < 4; i++) {
                if ([responder respondsToSelector:selectors[i]]) {
                    NSLog(@"[SCInsta] Manual seen: calling %@ on IGStoryViewerViewController", NSStringFromSelector(selectors[i]));
                    if (selectors[i] == @selector(markStoryAsSeen:)) {
                        [responder performSelector:selectors[i] withObject:nil];
                    } else {
                        [responder performSelector:selectors[i]];
                    }
                    didMark = YES;
                }
            }
        }
        // IGStoryFullscreenSectionController (might be in responder chain as next responder of a child VC)
        if ([responder isKindOfClass:NSClassFromString(@"IGStoryFullscreenSectionController")]) {
            SEL selectors[] = {
                @selector(markItemAsSeen:), @selector(markCurrentItemAsSeen),
                @selector(sendSeenRequestForCurrentItem)
            };
            for (int i = 0; i < 3; i++) {
                if ([responder respondsToSelector:selectors[i]]) {
                    NSLog(@"[SCInsta] Manual seen: calling %@ on IGStoryFullscreenSectionController", NSStringFromSelector(selectors[i]));
                    if (selectors[i] == @selector(markItemAsSeen:)) {
                        [responder performSelector:selectors[i] withObject:nil];
                    } else {
                        [responder performSelector:selectors[i]];
                    }
                    didMark = YES;
                }
            }
        }
        responder = [responder nextResponder];
    }

#pragma clang diagnostic pop

    // Re-enable blocking
    sciSeenBypassActive = NO;

    if (didMark) {
        [SCIUtils showToastForDuration:1.5 title:@"Marked as seen"];
    } else {
        [SCIUtils showToastForDuration:2.0 title:@"Could not mark as seen" subtitle:@"Method not found"];
    }
}
%end
