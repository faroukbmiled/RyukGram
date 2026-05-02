// Story seen-receipt blocking. Legacy + Sundial uploads are Swift-dispatched
// via a `networker` ivar — we cache the uploaders at init and nil the ivar
// while the active owner is blocked. `keep_seen_visual_local` ON runs orig
// (local stores update, server blocked). OFF skips orig (full block).

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

static void sciStateRestore(void);

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

static BOOL sciIsPKAllowed(id media) {
	if (!media || sciAllowedSeenPKs.count == 0) return NO;

	NSString *pk = sciString(sciCall(media, @selector(pk)));
	if (!pk.length || ![sciAllowedSeenPKs containsObject:pk]) return NO;

	if ([SCIExcludedStoryUsers isFeatureEnabled] && ![SCIExcludedStoryUsers isUserPKExcluded:pk]) return NO;
	return YES;
}

// ============ Feature gates ============

static BOOL sciShouldBlockSeenNetwork(void) {
	if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return NO;
	if (sciSeenBypassActive || sciToggleAllowsSeen()) return NO;
	return !sciIsCurrentStoryOwnerExcluded();
}

static BOOL sciShouldBlockSeenVisual(void) {
	if (![SCIUtils getBoolPref:@"no_seen_receipt"] || [SCIUtils getBoolPref:@"keep_seen_visual_local"]) return NO;
	if (sciSeenBypassActive || sciToggleAllowsSeen()) return NO;
	return !sciIsCurrentStoryOwnerExcluded();
}

// Per-instance gate — tray/item/ring models may not match the active VC.
static BOOL sciShouldBlockSeenVisualForObj(id obj) {
	if (![SCIUtils getBoolPref:@"no_seen_receipt"] || [SCIUtils getBoolPref:@"keep_seen_visual_local"]) return NO;
	if (sciSeenBypassActive || sciToggleAllowsSeen()) return NO;
	return !sciIsObjectStoryOwnerExcluded(obj);
}

// ============ Legacy network-upload hooks ============

%hook IGStorySeenStateUploader

- (void)uploadSeenStateWithMedia:(id)arg1 {
	if (sciShouldBlockSeenNetwork() && !sciIsPKAllowed(arg1)) return;
	%orig;
}

- (void)uploadSeenState {
	if (sciShouldBlockSeenNetwork()) return;
	%orig;
}

- (void)_uploadSeenState:(id)arg1 {
	if (sciShouldBlockSeenNetwork() && !sciIsPKAllowed(arg1)) return;
	%orig;
}

- (void)sendSeenReceipt:(id)arg1 {
	if (sciShouldBlockSeenNetwork() && !sciIsPKAllowed(arg1)) return;
	%orig;
}

%end

// ============ Visual-seen hooks + auto-advance ============

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

- (void)sendSeenRequestForCurrentItem {
	if (sciShouldBlockSeenNetwork()) return;
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

// ============ Active story VC tracking ============

__weak UIViewController *sciActiveStoryVC = nil;

%hook IGStoryViewerViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	sciActiveStoryVC = self;
}

- (void)viewWillDisappear:(BOOL)animated {
	if (sciActiveStoryVC == (UIViewController *)self) sciActiveStoryVC = nil;
	sciStateRestore();
	%orig;
}

- (void)fullscreenSectionController:(id)arg1 didMarkItemAsSeen:(id)arg2 {
	if (sciShouldBlockSeenVisual() && !sciIsPKAllowed(arg2)) return;
	%orig;
}

%end

// ============ Networker-ivar swap ============

static __weak id sciLegacyUploader = nil;
static __weak id sciSundialManager = nil;

static id (*orig_pendingStoreInit)(id, SEL, id, id, id, BOOL);
static id new_pendingStoreInit(id self, SEL _cmd, id sessionPK, id uploader, id fileMgr, BOOL bgTask) {
	if (uploader) sciLegacyUploader = uploader;
	return orig_pendingStoreInit(self, _cmd, sessionPK, uploader, fileMgr, bgTask);
}

static id (*orig_sundialMgrInit)(id, SEL, id, id, id, id);
static id new_sundialMgrInit(id self, SEL _cmd, id networker, id diskMgr, id launcherSet, id announcer) {
	id result = orig_sundialMgrInit(self, _cmd, networker, diskMgr, launcherSet, announcer);
	if (result) sciSundialManager = result;
	return result;
}

static Ivar sciNetworkerIvar(id obj) {
	if (!obj) return NULL;
	Ivar ivar = sciFindIvar([obj class], "networker");
	return ivar ?: sciFindIvar([obj class], "_networker");
}

static id sciManagerUploader(id manager, NSString *ivarName) {
	if (!manager) return nil;
	Ivar ivar = sciFindIvar([manager class], ivarName.UTF8String);
	return ivar ? object_getIvar(manager, ivar) : nil;
}

static void sciSaveAndSetNetworker(NSMutableDictionary *saved, NSString *key, id uploader, id newNetworker) {
	if (!uploader) return;

	Ivar ivar = sciNetworkerIvar(uploader);
	if (!ivar) return;

	id oldNetworker = object_getIvar(uploader, ivar);
	if (oldNetworker) saved[key] = oldNetworker;

	object_setIvar(uploader, ivar, newNetworker);
}

static void sciRestoreNetworker(NSDictionary *saved, NSString *key, id uploader) {
	id original = saved[key];
	if (!uploader || !original) return;

	Ivar ivar = sciNetworkerIvar(uploader);
	if (ivar) object_setIvar(uploader, ivar, original);
}

// Swap each cached uploader's networker ivar; saved dict is used to restore.
static NSDictionary *sciSwapNetworkers(id newNetworker) {
	NSMutableDictionary *saved = [NSMutableDictionary dictionary];

	@try {
		id manager = sciSundialManager;
		sciSaveAndSetNetworker(saved, @"legacy", sciLegacyUploader, newNetworker);
		sciSaveAndSetNetworker(saved, @"seenStateUploader", sciManagerUploader(manager, @"seenStateUploader"), newNetworker);
		sciSaveAndSetNetworker(saved, @"seenStateUploaderDeprecated", sciManagerUploader(manager, @"seenStateUploaderDeprecated"), newNetworker);
	} @catch (__unused id e) {}

	return saved;
}

static void sciRestoreNetworkers(NSDictionary *saved) {
	if (!saved.count) return;

	@try {
		id manager = sciSundialManager;
		sciRestoreNetworker(saved, @"legacy", sciLegacyUploader);
		sciRestoreNetworker(saved, @"seenStateUploader", sciManagerUploader(manager, @"seenStateUploader"));
		sciRestoreNetworker(saved, @"seenStateUploaderDeprecated", sciManagerUploader(manager, @"seenStateUploaderDeprecated"));
	} @catch (__unused id e) {}
}

// Idempotent block/restore. Guard prevents double-swap clobbering originals.
static BOOL sciNetBlocked = NO;
static NSDictionary *sciNetSaved = nil;

static void sciStateBlock(void) {
	if (sciNetBlocked) return;
	sciNetSaved = sciSwapNetworkers(nil);
	sciNetBlocked = YES;
}

static void sciStateRestore(void) {
	if (!sciNetBlocked) return;
	sciRestoreNetworkers(sciNetSaved);
	sciNetSaved = nil;
	sciNetBlocked = NO;
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
	} @catch (__unused id e) {
		return nil;
	}
}

static BOOL sciShouldBlockOwnerPK(NSString *ownerPK) {
	if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return NO;
	if (![SCIExcludedStoryUsers isFeatureEnabled]) return YES;
	return ownerPK.length && ![SCIExcludedStoryUsers isUserPKExcluded:ownerPK];
}

// Mark-seen delegate: restore on non-blocked owners, block + run orig on
// blocked owners when split-mode is on, skip orig when it's off.
typedef void (*SCIOrigDelegateMarkSeen)(id, SEL, id, id);

static void sciHandleDelegateMarkSeen(SCIOrigDelegateMarkSeen orig, id self, SEL _cmd, id ctrl, id item) {
	if (!orig) return;

	if (sciSeenBypassActive || sciToggleAllowsSeen() || ![SCIUtils getBoolPref:@"no_seen_receipt"]) {
		sciStateRestore();
		orig(self, _cmd, ctrl, item);
		return;
	}

	if (!sciShouldBlockOwnerPK(sciExtractOwnerPKFromItem(item))) {
		sciStateRestore();
		orig(self, _cmd, ctrl, item);
		return;
	}

	if (![SCIUtils getBoolPref:@"keep_seen_visual_local"]) {
		sciStateRestore();
		return;
	}

	sciStateBlock();

	@try {
		orig(self, _cmd, ctrl, item);
	} @catch (__unused id e) {
		sciStateRestore();
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
	sciHookIfExists(NSClassFromString(@"IGStoryPendingSeenStateStore"), NSSelectorFromString(@"initWithUserSessionPK:uploader:fileManager:uploadInBackgroundTask:"), (IMP)new_pendingStoreInit, (IMP *)&orig_pendingStoreInit);
	sciHookIfExists(NSClassFromString(@"_TtC23IGSundialSeenStateSwift25IGSundialSeenStateManager"), NSSelectorFromString(@"initWithNetworker:diskManager:launcherSet:seenStateManagerAnnouncer:"), (IMP)new_sundialMgrInit, (IMP *)&orig_sundialMgrInit);

	// Mark-as-seen delegate. Each class gets its own original IMP; do not
	// reuse one orig pointer here or later hooks can overwrite it.
	SEL delegateSel = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");

	sciHookIfExists(NSClassFromString(@"IGStoryViewerViewController"), delegateSel, (IMP)new_delegateViewer, (IMP *)&orig_delegateViewer);
	sciHookIfExists(NSClassFromString(@"IGStoryViewerUpdater"), delegateSel, (IMP)new_delegateUpdater, (IMP *)&orig_delegateUpdater);
	sciHookIfExists(NSClassFromString(@"IGStoryFullscreenViewModel"), delegateSel, (IMP)new_delegateViewModel, (IMP *)&orig_delegateViewModel);
	sciHookIfExists(NSClassFromString(@"IGStoriesManager"), delegateSel, (IMP)new_delegateManager, (IMP *)&orig_delegateManager);
}