// Story seen receipt blocking + visual seen state blocking
#import "StoryHelpers.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

BOOL sciSeenBypassActive = NO;
NSMutableSet *sciAllowedSeenPKs = nil;

void sciAllowSeenForPK(id media) {
    if (!media) return;
    id pk = sciCall(media, @selector(pk));
    if (!pk) return;
    if (!sciAllowedSeenPKs) sciAllowedSeenPKs = [NSMutableSet set];
    [sciAllowedSeenPKs addObject:[NSString stringWithFormat:@"%@", pk]];
}

static BOOL sciIsPKAllowed(id media) {
    if (!media || !sciAllowedSeenPKs || sciAllowedSeenPKs.count == 0) return NO;
    id pk = sciCall(media, @selector(pk));
    if (!pk) return NO;
    return [sciAllowedSeenPKs containsObject:[NSString stringWithFormat:@"%@", pk]];
}

static BOOL sciShouldBlockSeenNetwork() {
    if (sciSeenBypassActive) return NO;
    return [SCIUtils getBoolPref:@"no_seen_receipt"];
}

static BOOL sciShouldBlockSeenVisual() {
    if (sciSeenBypassActive) return NO;
    return [SCIUtils getBoolPref:@"no_seen_receipt"] && [SCIUtils getBoolPref:@"no_seen_visual"];
}

// network seen blocking
%hook IGStorySeenStateUploader
- (void)uploadSeenStateWithMedia:(id)arg1 {
    if (!sciSeenBypassActive && sciShouldBlockSeenNetwork() && !sciIsPKAllowed(arg1)) return;
    %orig;
}
- (void)uploadSeenState {
    if (!sciSeenBypassActive && sciShouldBlockSeenNetwork() && !(sciAllowedSeenPKs && sciAllowedSeenPKs.count > 0)) return;
    %orig;
}
- (void)_uploadSeenState:(id)arg1 {
    if (!sciSeenBypassActive && sciShouldBlockSeenNetwork() && !sciIsPKAllowed(arg1)) return;
    %orig;
}
- (void)sendSeenReceipt:(id)arg1 {
    if (!sciSeenBypassActive && sciShouldBlockSeenNetwork() && !sciIsPKAllowed(arg1)) return;
    %orig;
}
- (id)networker { return %orig; }
%end

// visual seen blocking + story auto-advance
%hook IGStoryFullscreenSectionController
- (void)markItemAsSeen:(id)arg1 { if (sciShouldBlockSeenVisual() && !sciIsPKAllowed(arg1)) return; %orig; }
- (void)_markItemAsSeen:(id)arg1 { if (sciShouldBlockSeenVisual() && !sciIsPKAllowed(arg1)) return; %orig; }
- (void)storySeenStateDidChange:(id)arg1 { if (sciShouldBlockSeenVisual()) return; %orig; }
- (void)sendSeenRequestForCurrentItem { if (sciShouldBlockSeenVisual()) return; %orig; }
- (void)markCurrentItemAsSeen { if (sciShouldBlockSeenVisual()) return; %orig; }
- (void)storyPlayerMediaViewDidPlayToEnd:(id)arg1 {
    if ([SCIUtils getBoolPref:@"stop_story_auto_advance"]) return;
    %orig;
}
- (void)advanceToNextReelForAutoScroll {
    if ([SCIUtils getBoolPref:@"stop_story_auto_advance"]) return;
    %orig;
}
%end

%hook IGStoryViewerViewController
- (void)fullscreenSectionController:(id)arg1 didMarkItemAsSeen:(id)arg2 {
    if (sciShouldBlockSeenVisual() && !sciIsPKAllowed(arg2)) return;
    %orig;
}
%end

%hook IGStoryTrayViewModel
- (void)markAsSeen { if (sciShouldBlockSeenVisual()) return; %orig; }
- (void)setHasUnseenMedia:(BOOL)arg1 { if (sciShouldBlockSeenVisual()) { %orig(YES); return; } %orig; }
- (BOOL)hasUnseenMedia { if (sciShouldBlockSeenVisual()) return YES; return %orig; }
- (void)setIsSeen:(BOOL)arg1 { if (sciShouldBlockSeenVisual()) { %orig(NO); return; } %orig; }
- (BOOL)isSeen { if (sciShouldBlockSeenVisual()) return NO; return %orig; }
%end

%hook IGStoryItem
- (void)setHasSeen:(BOOL)arg1 { if (sciShouldBlockSeenVisual()) { %orig(NO); return; } %orig; }
- (BOOL)hasSeen { if (sciShouldBlockSeenVisual()) return NO; return %orig; }
%end

%hook IGStoryGradientRingView
- (void)setIsSeen:(BOOL)arg1 { if (sciShouldBlockSeenVisual()) { %orig(NO); return; } %orig; }
- (void)setSeen:(BOOL)arg1 { if (sciShouldBlockSeenVisual()) { %orig(NO); return; } %orig; }
- (void)updateRingForSeenState:(BOOL)arg1 { if (sciShouldBlockSeenVisual()) { %orig(NO); return; } %orig; }
%end

// ============ MARK SEEN ON STORY LIKE ============
// Story likes are dispatched through several classes — IGSundialViewerControlsOverlayController,
// IGStoryLikesInteractionControllingImpl, and IGSundialLikeButton. Hook every
// known entry so any UI path (heart button, future double-tap, etc.) is caught.
// On a like, we defer to the manual seen-button handler in OverlayButtons.xm
// (sciMarkSeenTapped:) which is the only flow IG actually treats as a real seen.

static __weak UIViewController *sciActiveStoryVC = nil;

%hook IGStoryViewerViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    sciActiveStoryVC = self;
}
- (void)viewWillDisappear:(BOOL)animated {
    if (sciActiveStoryVC == (UIViewController *)self) sciActiveStoryVC = nil;
    %orig;
}
%end

static UIView *sciFindStoryOverlayView(UIViewController *vc) {
    if (!vc) return nil;
    Class targetCls = NSClassFromString(@"IGStoryFullscreenOverlayView");
    if (!targetCls) return nil;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:vc.view];
    while (stack.count > 0) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if ([v isKindOfClass:targetCls]) return v;
        for (UIView *sub in v.subviews) [stack addObject:sub];
    }
    return nil;
}

static void sciMarkActiveStorySeen(void) {
    if (![SCIUtils getBoolPref:@"seen_on_story_like"]) return;
    UIView *overlay = sciFindStoryOverlayView(sciActiveStoryVC);
    if (!overlay) return;
    SEL sel = NSSelectorFromString(@"sciMarkSeenTapped:");
    if ([overlay respondsToSelector:sel]) {
        ((void(*)(id, SEL, id))objc_msgSend)(overlay, sel, nil);
    }
}

static void (*orig_didLikeSundial)(id, SEL, id);
static void new_didLikeSundial(id self, SEL _cmd, id pk) {
    orig_didLikeSundial(self, _cmd, pk);
    sciMarkActiveStorySeen();
}

static void (*orig_overlaySetIsLiked)(id, SEL, BOOL, BOOL);
static void new_overlaySetIsLiked(id self, SEL _cmd, BOOL isLiked, BOOL animated) {
    orig_overlaySetIsLiked(self, _cmd, isLiked, animated);
    if (isLiked) sciMarkActiveStorySeen();
}

static void (*orig_handleLikeTap)(id, SEL, id);
static void new_handleLikeTap(id self, SEL _cmd, id button) {
    orig_handleLikeTap(self, _cmd, button);
    sciMarkActiveStorySeen();
}

static void (*orig_likeButtonSetIsLiked)(id, SEL, BOOL, BOOL);
static void new_likeButtonSetIsLiked(id self, SEL _cmd, BOOL isLiked, BOOL animated) {
    orig_likeButtonSetIsLiked(self, _cmd, isLiked, animated);
    if (isLiked) sciMarkActiveStorySeen();
}

%ctor {
    Class overlayCtl = NSClassFromString(@"IGSundialViewerControlsOverlayController");
    if (overlayCtl) {
        SEL didLike = NSSelectorFromString(@"didLikeSundialWithMediaPK:");
        if (class_getInstanceMethod(overlayCtl, didLike))
            MSHookMessageEx(overlayCtl, didLike, (IMP)new_didLikeSundial, (IMP *)&orig_didLikeSundial);

        SEL setLiked = @selector(setIsLiked:animated:);
        if (class_getInstanceMethod(overlayCtl, setLiked))
            MSHookMessageEx(overlayCtl, setLiked, (IMP)new_overlaySetIsLiked, (IMP *)&orig_overlaySetIsLiked);
    }

    Class likesImpl = NSClassFromString(@"IGStoryLikesInteractionControllingImpl");
    if (likesImpl) {
        SEL handleTap = NSSelectorFromString(@"handleStoryLikeTapWithButton:");
        if (class_getInstanceMethod(likesImpl, handleTap))
            MSHookMessageEx(likesImpl, handleTap, (IMP)new_handleLikeTap, (IMP *)&orig_handleLikeTap);
    }

    Class likeBtn = NSClassFromString(@"IGSundialViewerUFI.IGSundialLikeButton");
    if (likeBtn) {
        SEL setLiked = @selector(setIsLiked:animated:);
        if (class_getInstanceMethod(likeBtn, setLiked))
            MSHookMessageEx(likeBtn, setLiked, (IMP)new_likeButtonSetIsLiked, (IMP *)&orig_likeButtonSetIsLiked);
    }

}
