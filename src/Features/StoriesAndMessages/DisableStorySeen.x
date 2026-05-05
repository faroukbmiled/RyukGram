// Story seen-receipt blocking. Lets IG's natural pipeline run for visual
// state and filters server uploads at IGStorySeenState construction —
// every `/media/seen/` request body is built from one of those snapshots,
// so dropping blocked-owner keys at construction prevents the receipt
// reaching the wire across all flush paths (mid-session, dismiss, restart).
// Per-PK allow-set (`sciAllowedSeenPKs`) lets the eye button slot one
// explicit media into the same batch flush.

#import "StoryHelpers.h"
#import "SCIStoryInteractionPipeline.h"
#import "SCIExcludedStoryUsers.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

BOOL sciSeenBypassActive = NO;
BOOL sciAdvanceBypassActive = NO;
BOOL sciStorySeenToggleEnabled = NO;
NSMutableSet *sciAllowedSeenPKs = nil;

extern BOOL sciIsCurrentStoryOwnerExcluded(void);
extern BOOL sciIsObjectStoryOwnerExcluded(id obj);

static inline BOOL sciToggleAllowsSeen(void) {
	return [[SCIUtils getStringPref:@"story_seen_mode"] isEqualToString:@"toggle"] && sciStorySeenToggleEnabled;
}

static inline NSString *sciString(id value) {
	return value ? [NSString stringWithFormat:@"%@", value] : nil;
}

static Ivar sciFindIvar(Class cls, const char *name) {
	for (Class c = cls; c; c = class_getSuperclass(c)) {
		Ivar ivar = class_getInstanceVariable(c, name);
		if (ivar) return ivar;
	}
	return NULL;
}

void sciAllowSeenForPK(id media) {
	NSString *pk = sciString(sciCall(media, @selector(pk)));
	if (!pk.length) return;
	if (!sciAllowedSeenPKs) sciAllowedSeenPKs = [NSMutableSet set];
	[sciAllowedSeenPKs addObject:pk];
}

static BOOL sciIsMediaPKAllowed(NSString *pk) {
	return pk.length > 0 && sciAllowedSeenPKs.count > 0 && [sciAllowedSeenPKs containsObject:pk];
}

static BOOL sciIsPKAllowed(id media) {
	if (!media) return NO;
	return sciIsMediaPKAllowed(sciString(sciCall(media, @selector(pk))));
}

static NSString *sciExtractOwnerPKFromItem(id item) {
	if (!item) return nil;
	@try {
		id reelPK = sciCall(item, NSSelectorFromString(@"reelPk"));
		if (reelPK) return [reelPK description];
		id media = sciCall(item, @selector(media)) ?: item;
		id user = sciCall(media, @selector(user)) ?: sciCall(media, @selector(owner));
		if (!user) return nil;
		Ivar pkIvar = sciFindIvar([user class], "_pk");
		id pk = pkIvar ? object_getIvar(user, pkIvar) : sciCall(user, @selector(pk));
		return pk ? [pk description] : nil;
	} @catch (__unused id e) { return nil; }
}

static BOOL sciShouldBlockOwnerPK(NSString *ownerPK) {
	if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return NO;
	if (sciSeenBypassActive || sciToggleAllowsSeen()) return NO;
	if (![SCIExcludedStoryUsers isFeatureEnabled]) return YES;
	return ownerPK.length && ![SCIExcludedStoryUsers isUserPKExcluded:ownerPK];
}

// ============ Visual gates ============

static BOOL sciShouldBlockSeenVisual(void) {
	if (![SCIUtils getBoolPref:@"no_seen_receipt"] || [SCIUtils getBoolPref:@"keep_seen_visual_local"]) return NO;
	if (sciSeenBypassActive || sciToggleAllowsSeen()) return NO;
	return !sciIsCurrentStoryOwnerExcluded();
}

static BOOL sciShouldBlockSeenVisualForObj(id obj) {
	if (![SCIUtils getBoolPref:@"no_seen_receipt"] || [SCIUtils getBoolPref:@"keep_seen_visual_local"]) return NO;
	if (sciSeenBypassActive || sciToggleAllowsSeen()) return NO;
	return !sciIsObjectStoryOwnerExcluded(obj);
}

// ============ Visual-seen hooks ============

%hook IGStoryFullscreenSectionController

- (void)markItemAsSeen:(id)arg1 {
	if (sciShouldBlockSeenVisual() && !sciIsPKAllowed(arg1)) return;
	%orig;
}

- (void)_markItemAsSeen:(id)arg1 {
	if (sciShouldBlockSeenVisual() && !sciIsPKAllowed(arg1)) return;
	%orig;
}

- (void)storySeenStateDidChange:(id)arg1 {
	if (sciShouldBlockSeenVisual()) return;
	%orig;
}

- (void)markCurrentItemAsSeen {
	if (sciShouldBlockSeenVisual()) return;
	%orig;
}

- (void)storyPlayerMediaViewDidPlayToEnd:(id)arg1 {
	if (!sciAdvanceBypassActive && [SCIUtils getBoolPref:@"stop_story_auto_advance"]) return;
	%orig;
}

- (void)advanceToNextReelForAutoScroll {
	if (!sciAdvanceBypassActive && [SCIUtils getBoolPref:@"stop_story_auto_advance"]) return;
	%orig;
}

%end

%hook IGStoryTrayViewModel

- (void)markAsSeen {
	if (sciShouldBlockSeenVisualForObj(self)) return;
	%orig;
}

- (void)setHasUnseenMedia:(BOOL)arg1 {
	if (sciShouldBlockSeenVisualForObj(self)) {
		%orig(YES);
		return;
	}
	%orig;
}

- (BOOL)hasUnseenMedia {
	return sciShouldBlockSeenVisualForObj(self) ? YES : %orig;
}

- (void)setIsSeen:(BOOL)arg1 {
	if (sciShouldBlockSeenVisualForObj(self)) {
		%orig(NO);
		return;
	}
	%orig;
}

- (BOOL)isSeen {
	return sciShouldBlockSeenVisualForObj(self) ? NO : %orig;
}

%end

%hook IGStoryItem

- (void)setHasSeen:(BOOL)arg1 {
	if (sciShouldBlockSeenVisualForObj(self)) {
		%orig(NO);
		return;
	}
	%orig;
}

- (BOOL)hasSeen {
	return sciShouldBlockSeenVisualForObj(self) ? NO : %orig;
}

%end

%hook IGStoryGradientRingView

- (void)setIsSeen:(BOOL)arg1 {
	if (sciShouldBlockSeenVisual()) {
		%orig(NO);
		return;
	}
	%orig;
}

- (void)setSeen:(BOOL)arg1 {
	if (sciShouldBlockSeenVisual()) {
		%orig(NO);
		return;
	}
	%orig;
}

- (void)updateRingForSeenState:(BOOL)arg1 {
	if (sciShouldBlockSeenVisual()) {
		%orig(NO);
		return;
	}
	%orig;
}

%end

// ============ Active story VC tracking + dismiss flush ============

static NSHashTable *sciPendingStores = nil;

static id (*sciOrigPendingStoreInit)(id, SEL, id, id, id, BOOL);
static id sciNewPendingStoreInit(id self, SEL _cmd, id sessionPK, id uploader, id fileMgr, BOOL bgTask) {
	id result = sciOrigPendingStoreInit(self, _cmd, sessionPK, uploader, fileMgr, bgTask);
	if (result) {
		if (!sciPendingStores) sciPendingStores = [NSHashTable weakObjectsHashTable];
		[sciPendingStores addObject:result];
	}
	return result;
}

// Force-fire each cached IGStoryPendingSeenStateStore's `_uploadTimer`
// (an FBTimer) so an eye-press immediately followed by dismiss still
// flushes within the session instead of waiting for the next launch.
static void sciFlushPendingStores(void) {
	if (!sciPendingStores) return;
	SEL fbFire = NSSelectorFromString(@"_fireTheTimer");
	for (id store in sciPendingStores.allObjects) {
		@try {
			Ivar t = sciFindIvar([store class], "_uploadTimer");
			if (!t) continue;
			id timer = object_getIvar(store, t);
			if (timer && [timer respondsToSelector:fbFire]) {
				((void(*)(id, SEL))objc_msgSend)(timer, fbFire);
			}
		} @catch (__unused id e) {}
	}
}

__weak UIViewController *sciActiveStoryVC = nil;

%hook IGStoryViewerViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	sciActiveStoryVC = self;
}

- (void)viewWillDisappear:(BOOL)animated {
	if (sciActiveStoryVC == (UIViewController *)self) sciActiveStoryVC = nil;
	if ([SCIUtils getBoolPref:@"no_seen_receipt"] && sciAllowedSeenPKs.count > 0) {
		sciFlushPendingStores();
	}
	%orig;
}

%end

// ============ Mark-seen delegate hook ============
//
// Visual-local mode runs orig (visual updates locally, server upload gets
// filtered at IGStorySeenState construction). Hard-block mode skips orig
// so IG's local state never marks seen.

typedef void (*SCIOrigDelegateMarkSeen)(id, SEL, id, id);

static void sciHandleDelegateMarkSeen(SCIOrigDelegateMarkSeen orig, id self, SEL _cmd, id ctrl, id item) {
	if (!orig) return;

	if (sciSeenBypassActive || sciToggleAllowsSeen() || ![SCIUtils getBoolPref:@"no_seen_receipt"]) {
		orig(self, _cmd, ctrl, item);
		return;
	}

	NSString *ownerPK = sciExtractOwnerPKFromItem(item);
	if (!sciShouldBlockOwnerPK(ownerPK)) {
		orig(self, _cmd, ctrl, item);
		return;
	}

	if ([SCIUtils getBoolPref:@"keep_seen_visual_local"]) {
		orig(self, _cmd, ctrl, item);
	}
}

static SCIOrigDelegateMarkSeen orig_delegateViewer = NULL;
static SCIOrigDelegateMarkSeen orig_delegateUpdater = NULL;
static SCIOrigDelegateMarkSeen orig_delegateViewModel = NULL;
static SCIOrigDelegateMarkSeen orig_delegateManager = NULL;

static void new_delegateViewer(id self, SEL _cmd, id ctrl, id item) {
	sciHandleDelegateMarkSeen(orig_delegateViewer, self, _cmd, ctrl, item);
}

static void new_delegateUpdater(id self, SEL _cmd, id ctrl, id item) {
	sciHandleDelegateMarkSeen(orig_delegateUpdater, self, _cmd, ctrl, item);
}

static void new_delegateViewModel(id self, SEL _cmd, id ctrl, id item) {
	sciHandleDelegateMarkSeen(orig_delegateViewModel, self, _cmd, ctrl, item);
}

static void new_delegateManager(id self, SEL _cmd, id ctrl, id item) {
	sciHandleDelegateMarkSeen(orig_delegateManager, self, _cmd, ctrl, item);
}

// ============ Seen-state filter ============
//
// Dict key encodes the media identity itself:
//   "<innerMediaId>_<mediaOwnerPK>_<reelOwnerPK>"
// First two segments form the full mediaPK that `sciAllowedSeenPKs`
// stores. Values are timestamp tuples (`<takenAt>_<seenAt>`); we never
// look inside them.

static id sciFilterSeenContainer(id container) {
	if (![container isKindOfClass:[NSDictionary class]]) return container;
	NSDictionary *dict = (NSDictionary *)container;
	if (!dict.count) return dict;

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	for (NSString *key in dict) {
		NSArray *segs = [key componentsSeparatedByString:@"_"];
		NSString *ownerPK = segs.lastObject;
		NSString *mediaPK = segs.count >= 2
			? [NSString stringWithFormat:@"%@_%@", segs[0], segs[1]]
			: key;

		if (!sciShouldBlockOwnerPK(ownerPK)) {
			out[key] = dict[key];
			continue;
		}
		if (sciAllowedSeenPKs.count && [sciAllowedSeenPKs containsObject:mediaPK]) {
			out[key] = dict[key];
		}
	}
	return out;
}

%hook IGStorySeenState

- (id)initWithReelSeenDictionary:(id)reel
              liveSeenDictionary:(id)live
           reelSkippedDictionary:(id)reelSkipped
           liveSkippedDictionary:(id)liveSkipped
                 containerModule:(id)mod
                    pushCategory:(id)cat
                    forceSeenIds:(id)forceSeen {
	if ([SCIUtils getBoolPref:@"no_seen_receipt"] && !sciSeenBypassActive && !sciToggleAllowsSeen()) {
		reel        = sciFilterSeenContainer(reel);
		live        = sciFilterSeenContainer(live);
		reelSkipped = sciFilterSeenContainer(reelSkipped);
		liveSkipped = sciFilterSeenContainer(liveSkipped);
	}
	return %orig(reel, live, reelSkipped, liveSkipped, mod, cat, forceSeen);
}

%end

// ============ Like → mark-seen side effects ============

static void (*orig_didLikeSundial)(id, SEL, id);
static void new_didLikeSundial(id self, SEL _cmd, id pk) {
	if (orig_didLikeSundial) orig_didLikeSundial(self, _cmd, pk);
	sciStoryInteractionSideEffects(SCIStoryInteractionLike);
}

static void (*orig_overlaySetIsLiked)(id, SEL, BOOL, BOOL);
static void new_overlaySetIsLiked(id self, SEL _cmd, BOOL isLiked, BOOL animated) {
	if (orig_overlaySetIsLiked) orig_overlaySetIsLiked(self, _cmd, isLiked, animated);
	if (isLiked) sciStoryInteractionSideEffects(SCIStoryInteractionLike);
}

static void (*orig_likeButtonSetIsLiked)(id, SEL, BOOL, BOOL);
static void new_likeButtonSetIsLiked(id self, SEL _cmd, BOOL isLiked, BOOL animated) {
	if (orig_likeButtonSetIsLiked) orig_likeButtonSetIsLiked(self, _cmd, isLiked, animated);
	if (isLiked) sciStoryInteractionSideEffects(SCIStoryInteractionLike);
}

static void sciHookIfExists(Class cls, SEL sel, IMP replacement, IMP *original) {
	if (cls && class_getInstanceMethod(cls, sel)) {
		MSHookMessageEx(cls, sel, replacement, original);
	}
}

%ctor {
	Class overlayController = NSClassFromString(@"IGSundialViewerControlsOverlayController");
	SEL setLikedSel = @selector(setIsLiked:animated:);

	sciHookIfExists(overlayController, NSSelectorFromString(@"didLikeSundialWithMediaPK:"), (IMP)new_didLikeSundial, (IMP *)&orig_didLikeSundial);
	sciHookIfExists(overlayController, setLikedSel, (IMP)new_overlaySetIsLiked, (IMP *)&orig_overlaySetIsLiked);
	sciHookIfExists(NSClassFromString(@"IGSundialViewerUFI.IGSundialLikeButton"), setLikedSel, (IMP)new_likeButtonSetIsLiked, (IMP *)&orig_likeButtonSetIsLiked);

	// Mark-seen delegate. Each class needs its own orig pointer — sharing
	// one across hooks lets a later registration clobber an earlier IMP.
	SEL delegateSel = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");
	sciHookIfExists(NSClassFromString(@"IGStoryViewerViewController"), delegateSel, (IMP)new_delegateViewer, (IMP *)&orig_delegateViewer);
	sciHookIfExists(NSClassFromString(@"IGStoryViewerUpdater"),         delegateSel, (IMP)new_delegateUpdater, (IMP *)&orig_delegateUpdater);
	sciHookIfExists(NSClassFromString(@"IGStoryFullscreenViewModel"),   delegateSel, (IMP)new_delegateViewModel, (IMP *)&orig_delegateViewModel);
	sciHookIfExists(NSClassFromString(@"IGStoriesManager"),             delegateSel, (IMP)new_delegateManager, (IMP *)&orig_delegateManager);

	sciHookIfExists(NSClassFromString(@"IGStoryPendingSeenStateStore"),
		NSSelectorFromString(@"initWithUserSessionPK:uploader:fileManager:uploadInBackgroundTask:"),
		(IMP)sciNewPendingStoreInit, (IMP *)&sciOrigPendingStoreInit);
}
