#import <substrate.h>
#import "InstagramHeaders.h"
#import "Tweak.h"
#import "Utils.h"
#import "SCIDefaults.h"
#import "Features/General/SCICacheManager.h"
#import "Features/General/SCIChangelog.h"
#include "../modules/fishhook/fishhook.h"

#define SCI_PREF(key) [SCIUtils getBoolPref:key]
#define SCI_SCREENSHOT_BLOCKED SCI_PREF(@"remove_screenshot_alert")
#define VOID_HANDLESCREENSHOT(orig) do { if (!SCI_SCREENSHOT_BLOCKED) { orig; } } while (0)
#define NONVOID_HANDLESCREENSHOT(orig) do { if (SCI_SCREENSHOT_BLOCKED) return nil; return orig; } while (0)
#define SCI_LG_SURFACES SCI_PREF(@"liquid_glass_surfaces")

NSString *SCIVersionString = @"v1.2.3";
BOOL dmVisualMsgsViewedButtonEnabled = false;

static BOOL sciSupportsLiquidGlassButtons(void) {if (@available(iOS 19.0, *)) {return YES;}return NO;}

static BOOL sciLiquidGlassButtonsEnabled(void) {return SCI_PREF(@"liquid_glass_buttons") && sciSupportsLiquidGlassButtons();}

static BOOL sciFlexEnabled(void) {return SCI_PREF(@"flex_app_launch") || SCI_PREF(@"flex_app_start") || SCI_PREF(@"flex_instagram");}

static BOOL sciShouldHideMetaAIRecipient(id obj) {
	return SCI_PREF(@"hide_meta_ai") && ([[obj recipient] threadName] && [[[obj recipient] threadName] isEqualToString:@"Meta AI"]);
}

static BOOL sciStringEquals(NSString *a, NSString *b) {
	return a && [a isEqualToString:b];
}

static NSString *sciSafeValue(id obj, NSString *key) {
	@try { return [obj valueForKey:key]; } @catch (__unused id e) { return nil; }
}



// MARK: - App lifecycle

%group SCIAppLifecycleGroup

%hook IGInstagramAppDelegate

- (_Bool)application:(UIApplication *)application willFinishLaunchingWithOptions:(id)arg2 {
	[[NSUserDefaults standardUserDefaults] setValue:@(sciLiquidGlassButtonsEnabled()) forKey:@"instagram.override.project.lucent.navigation"];
	return %orig;
}

- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
	BOOL result = %orig;
	BOOL openOnLaunch = SCI_PREF(@"tweak_settings_app_launch");
	double delay = openOnLaunch ? 0.0 : 5.0;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		BOOL firstRun = ![[[NSUserDefaults standardUserDefaults] objectForKey:@"SCInstaFirstRun"] isEqualToString:SCIVersionString];

		if (firstRun || SCI_PREF(@"tweak_settings_app_launch")) {
			NSLog(@"[SCInsta] First run — showing settings modal");
			[SCIUtils showSettingsVC:[self window]];
		}
	});

	return result;
}

- (void)applicationDidEnterBackground:(id)arg1 {
	%orig;
	[SCICacheManager runAutoClearIfDue];
}

%end

%hook IGTabBarController
- (void)viewDidAppear:(BOOL)animated {
	%orig;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ [SCIChangelog presentIfNewFromWindow:self.view.window];});
}

%end

%end

// MARK: - FLEX

%group SCIFlexGroup

%hook IGRootViewController
- (void)viewDidLoad {
	%orig;
	static BOOL didAddActiveObserver = NO;
	if (!didAddActiveObserver && SCI_PREF(@"flex_app_start")) {
		didAddActiveObserver = YES;
		[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
			if (SCI_PREF(@"flex_app_start")) {
				[[objc_getClass("FLEXManager") sharedManager] showExplorer];
			}
		}];
	}
	if (SCI_PREF(@"flex_instagram")) {
		UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
		longPress.minimumPressDuration = 1.0;
		longPress.numberOfTouchesRequired = 5;
		[self.view addGestureRecognizer:longPress];
	}
}

- (void)viewDidAppear:(BOOL)animated {
	%orig;

	static BOOL didShowFlexOnLaunch = NO;

	if (!didShowFlexOnLaunch && SCI_PREF(@"flex_app_launch")) {
		didShowFlexOnLaunch = YES;

		dispatch_async(dispatch_get_main_queue(), ^{
			[[objc_getClass("FLEXManager") sharedManager] showExplorer];
		});
	}
}

%new
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateBegan && SCI_PREF(@"flex_instagram")) {
		[[objc_getClass("FLEXManager") sharedManager] showExplorer];
	}
}

%end

%end

// MARK: - Liquid glass buttons, iOS 19+

%group SCILiquidGlassButtonsGroup
%hook IGDSLauncherConfig
- (_Bool)isLiquidGlassInAppNotificationEnabled {return [SCIUtils liquidGlassEnabledBool:%orig];}
- (_Bool)isLiquidGlassContextMenuEnabled {return [SCIUtils liquidGlassEnabledBool:%orig];}
- (_Bool)isLiquidGlassToastEnabled {return [SCIUtils liquidGlassEnabledBool:%orig];}
- (_Bool)isLiquidGlassToastPeekEnabled {return [SCIUtils liquidGlassEnabledBool:%orig];}
- (_Bool)isLiquidGlassAlertDialogEnabled {return [SCIUtils liquidGlassEnabledBool:%orig];}
- (_Bool)isLiquidGlassIconBarButtonEnabled {return [SCIUtils liquidGlassEnabledBool:%orig];}
%end
%end

// MARK: - Debug / bug report blocking

%group SCIDebugBlockGroup
%hook IGWindow
- (void)showDebugMenu {}
%end

%hook IGBugReportUploader
- (id)initWithNetworker:(id)arg1 pandoGraphQLService:(id)arg2 analyticsLogger:(id)arg3 userDefaults:(id)arg4 launcherSetProvider:(id)arg5 shouldPersistLastBugReportId:(id)arg6 {return nil;}
%end
%end

// MARK: - Screenshot blocking

%group SCIScreenshotBlockGroup
%hook IGStoryViewerContainerView
- (void)setShouldBlockScreenshot:(BOOL)arg1 viewModel:(id)arg2 {VOID_HANDLESCREENSHOT(%orig);}
%end
%hook IGDirectVisualMessageViewerSession
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {NONVOID_HANDLESCREENSHOT(%orig);}
%end
%hook IGDirectVisualMessageReplayService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {NONVOID_HANDLESCREENSHOT(%orig);}
%end
%hook IGDirectVisualMessageReportService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {NONVOID_HANDLESCREENSHOT(%orig);}
%end

%hook IGDirectVisualMessageScreenshotSafetyLogger
- (id)initWithUserSession:(id)arg1 entryPoint:(NSInteger)arg2 {
	if (!SCI_SCREENSHOT_BLOCKED) return %orig;
	return nil;
}

%end

%hook IGScreenshotObserver
- (id)initForController:(id)arg1 {NONVOID_HANDLESCREENSHOT(%orig);}
%end

%hook IGScreenshotObserverDelegate
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {VOID_HANDLESCREENSHOT(%orig);}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {VOID_HANDLESCREENSHOT(%orig);}
%end

%hook IGDirectMediaViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {VOID_HANDLESCREENSHOT(%orig);}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {VOID_HANDLESCREENSHOT(%orig);}
%end

%hook IGStoryViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {VOID_HANDLESCREENSHOT(%orig);}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {VOID_HANDLESCREENSHOT(%orig);}
%end

%hook IGSundialFeedViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {VOID_HANDLESCREENSHOT(%orig);}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {VOID_HANDLESCREENSHOT(%orig);}
%end

%hook IGDirectVisualMessageViewerController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {VOID_HANDLESCREENSHOT(%orig);}

- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {VOID_HANDLESCREENSHOT(%orig);}
%end
%end

// MARK: - Hide / filter UI items

%group SCIHideItemsGroup

%hook IGDirectInboxSearchListAdapterDataSource

- (id)objectsForListAdapter:(id)arg1 {
	NSArray *items = %orig();
	BOOL hideMeta = SCI_PREF(@"hide_meta_ai");
	BOOL hideChats = SCI_PREF(@"no_suggested_chats");

	if (!hideMeta && !hideChats) return items;

	NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];

	for (id obj in items) {
		BOOL hide = NO;

		if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) {
			NSString *uid = sciSafeValue(obj, @"uniqueIdentifier");
			NSString *title = sciSafeValue(obj, @"labelTitle");
			hide = (hideChats && sciStringEquals(uid, @"channels")) || (hideMeta && (sciStringEquals(title, @"Ask Meta AI") || sciStringEquals(title, @"AI")));
		} else if ([obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsPillsSectionViewModel)] || [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsSuggestedPromptViewModel)] || [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsSuggestedPromptLoggingViewModel)]) {
			hide = hideMeta;
		} else if ([obj isKindOfClass:%c(IGDirectRecipientCellViewModel)]) {
			hide = (hideChats && [[obj recipient] isBroadcastChannel]) || (hideMeta && (([obj sectionType] == 20) || ([obj sectionType] == 18) || sciStringEquals([[obj recipient] threadName], @"Meta AI")));
		}

		if (!hide) [out addObject:obj];
	}

	return out.copy;
}

%end

%hook IGDirectThreadCreationViewController

- (id)objectsForListAdapter:(id)arg1 {
	NSArray *items = %orig();
	BOOL hideMeta = SCI_PREF(@"hide_meta_ai"), hideUsers = SCI_PREF(@"no_suggested_users");
	if (!hideMeta && !hideUsers) return items;

	NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
	for (id obj in items) {
		BOOL hide = NO;

		if (hideMeta && [obj isKindOfClass:%c(IGDirectCreateChatCellViewModel)]) {hide = sciStringEquals(sciSafeValue(obj, @"title"), @"AI chats");
		} else if (hideMeta && [obj isKindOfClass:%c(IGDirectRecipientCellViewModel)]) {hide = sciStringEquals([[obj recipient] threadName], @"Meta AI");
		} else if (hideUsers && [obj isKindOfClass:%c(IGContactInvitesSearchUpsellViewModel)]) {hide = YES;}

		if (!hide) [out addObject:obj];
	}

	return out.copy;
}

%end

%hook IGDirectInboxListAdapterDataSource

- (id)objectsForListAdapter:(id)arg1 {
	NSArray *items = %orig();
	BOOL hideUsers = SCI_PREF(@"no_suggested_users"), hideNotes = SCI_PREF(@"hide_notes_tray");

	if (!hideUsers && !hideNotes) return items;

	NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
	for (id obj in items) {
		BOOL hide = NO;

		if ([obj isKindOfClass:%c(IGDirectInboxHeaderCellViewModel)]) {
			NSString *title = [obj title];
			hide = hideUsers && (sciStringEquals(title, @"Suggestions") || [title hasPrefix:@"Accounts to"]);
		} else if ([obj isKindOfClass:%c(IGDirectInboxSuggestedThreadCellViewModel)]) {hide = hideUsers;
		} else if ([obj isKindOfClass:%c(IGDiscoverPeopleItemConfiguration)] || [obj isKindOfClass:%c(IGDiscoverPeopleConnectionItemConfiguration)]) {hide = hideUsers;
		} else if ([obj isKindOfClass:%c(IGDirectNotesTrayRowViewModel)]) {hide = hideNotes;
		}

		if (!hide) [out addObject:obj];
	}

	return out.copy;
}
%end

%hook IGSearchListKitDataSource
- (id)objectsForListAdapter:(id)arg1 {
	NSArray *items = %orig();
	BOOL hideMeta = SCI_PREF(@"hide_meta_ai");
	BOOL hideUsers = SCI_PREF(@"no_suggested_users");

	if (!hideMeta && !hideUsers) return items;

	NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];

	for (id obj in items) {
		BOOL hide = NO;

		if (hideMeta) {
			if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) hide = sciStringEquals(sciSafeValue(obj, @"labelTitle"), @"Ask Meta AI");
			else if ([obj isKindOfClass:%c(IGSearchNullStateUpsellViewModel)] || [obj isKindOfClass:%c(IGSearchResultNestedGroupViewModel)]) hide = YES;
			else if ([obj isKindOfClass:%c(IGSearchResultViewModel)]) hide = ([obj itemType] == 6) || sciStringEquals([[obj title] string], @"meta.ai");
		}

		if (!hide && hideUsers) {
			if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) hide = sciStringEquals(sciSafeValue(obj, @"labelTitle"), @"Suggested for you");
			else if ([obj isKindOfClass:%c(IGDiscoverPeopleItemConfiguration)]) hide = YES;
			else if ([obj isKindOfClass:%c(IGSeeAllItemConfiguration)] && ((IGSeeAllItemConfiguration *)obj).destination == 4) hide = YES;
		}

		if (!hide) [out addObject:obj];
	}

	return out.copy;
}

%end

%hook IGMainStoryTrayDataSource
- (id)allItemsForTrayUsingCachedValue:(BOOL)cached {
	NSArray *items = %orig(cached);
	BOOL hideUsers = SCI_PREF(@"no_suggested_users"), hideAds = SCI_PREF(@"hide_ads");

	if (!hideUsers && !hideAds) return items;

	NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
	for (IGStoryTrayViewModel *obj in items) {
		BOOL hide = NO;

		if ([obj isKindOfClass:%c(IGStoryTrayViewModel)]) {
			if (hideUsers) {
				NSNumber *type = [obj valueForKey:@"type"];
				hide = [type isEqual:@(8)] || [type isEqual:@(9)];
			}
			if (!hide && hideAds) { hide = obj.isUnseenNux || [obj.pk isEqualToString:@"3538572169"];}
		}
		if (!hide) [out addObject:obj];
	}
	return out.copy;
}

%end

%hook IGStoryTraySectionController
- (void)storyTrayControllerShowSUPOGEducationBump {if (!SCI_PREF(@"no_suggested_users")) %orig;}
%end

%hook IGDSMenu

- (id)initWithMenuItems:(NSArray<IGDSMenuItem *> *)items edr:(BOOL)edr headerLabelText:(id)headerLabelText {
	BOOL hideMeta = SCI_PREF(@"hide_meta_ai");
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];

	for (id obj in items) {
		NSString *title = sciSafeValue(obj, @"title");
		BOOL hide = hideMeta && (sciStringEquals(title, @"AI images") || sciStringEquals(title, @"Meta AI"));

		if (!hide) [out addObject:obj];
	}

	extern NSArray *sciMaybeAppendStoryExcludeMenuItem(NSArray *);
	extern NSArray *sciMaybeAppendStoryAudioMenuItem(NSArray *);
	extern NSArray *sciMaybeAppendStoryMentionsMenuItem(NSArray *);

	NSArray *finalItems = sciMaybeAppendStoryExcludeMenuItem(out.copy);
	finalItems = sciMaybeAppendStoryAudioMenuItem(finalItems);
	finalItems = sciMaybeAppendStoryMentionsMenuItem(finalItems);

	return %orig(finalItems, edr, headerLabelText);
}

%end

%end

// MARK: - Confirm / button behavior

%group SCIConfirmActionsGroup

%hook IGFeedItemUFICell

- (void)UFIButtonBarDidTapOnLike:(id)arg1 {
	if (!SCI_PREF(@"like_confirm")) return %orig;
	[SCIUtils showConfirmation:^{ %orig; } title:SCILocalized(@"Confirm like: Posts")];
}

- (void)UFIButtonBarDidTapOnRepost:(id)arg1 {
	if (!SCI_PREF(@"repost_confirm")) return %orig;
	[SCIUtils showConfirmation:^{ %orig; } title:SCILocalized(@"Confirm repost")];
}

- (void)UFIButtonBarDidLongPressOnRepost:(id)arg1 {
	if (!SCI_PREF(@"repost_confirm")) return %orig;
}

- (void)UFIButtonBarDidLongPressOnRepost:(id)arg1 withGestureRecognizer:(id)arg2 {
	if (!SCI_PREF(@"repost_confirm")) return %orig;
}

%end

%hook IGUFIInteractionCountsView
- (void)updateUFIWithButtonsConfig:(id)config interactionCountProvider:(id)provider {
	%orig;
	if (!SCI_PREF(@"hide_feed_repost")) return;
	Ivar rv = class_getInstanceVariable(object_getClass(self), "_repostView");
	Ivar uv = class_getInstanceVariable(object_getClass(self), "_undoRepostButton");
	if (rv) [object_getIvar((id)self, rv) setHidden:YES];
	if (uv) [object_getIvar((id)self, uv) setHidden:YES];
}
%end

%hook IGSundialViewerVerticalUFI
- (void)_didTapLikeButton:(id)arg1 {
	if (!SCI_PREF(@"like_confirm_reels")) return %orig;
	[SCIUtils showConfirmation:^{ %orig; } title:SCILocalized(@"Confirm like: Reels")];
}
- (void)_didLongPressLikeButton:(id)arg1 {
	if (!SCI_PREF(@"like_confirm_reels")) return %orig;
}
- (void)_didTapRepostButton {
	if (SCI_PREF(@"hide_reels_repost")) return;
	if (!SCI_PREF(@"repost_confirm")) return %orig;
	[SCIUtils showConfirmation:^{ %orig; } title:SCILocalized(@"Confirm repost")];
}

- (void)_didLongPressRepostButton:(id)arg1 {
	if (SCI_PREF(@"hide_reels_repost") || SCI_PREF(@"repost_confirm")) return;
	%orig;
}
%end

%hook IGSundialViewerUFIViewModel
- (BOOL)shouldShowRepostButton {
	return SCI_PREF(@"hide_reels_repost") ? NO : %orig;
}
%end
%end

// MARK: - Safe mode

%group SCISafeModeGroup

%hook IGSafeModeChecker

- (id)initWithInstacrashCounterProvider:(void *)provider crashThreshold:(unsigned long long)threshold {
	return SCI_PREF(@"disable_safe_mode") ? nil : %orig(provider, threshold);
}

- (unsigned long long)crashCount {
	return SCI_PREF(@"disable_safe_mode") ? 0 : %orig;
}

%end

%end

// MARK: - Liquid glass runtime hooks

static BOOL (*orig_swizzleToggle_isEnabled)(id, SEL) = NULL;
static BOOL (*orig_expHelper_isEnabled)(id, SEL) = NULL;
static BOOL (*orig_expHelper_isHomeFeed)(id, SEL) = NULL;

static BOOL new_swizzleToggle_isEnabled(id self, SEL _cmd) {
	return sciLiquidGlassButtonsEnabled() ? YES : (orig_swizzleToggle_isEnabled ? orig_swizzleToggle_isEnabled(self, _cmd) : NO);
}

static BOOL new_expHelper_isEnabled(id self, SEL _cmd) {
	return sciLiquidGlassButtonsEnabled() ? YES : (orig_expHelper_isEnabled ? orig_expHelper_isEnabled(self, _cmd) : NO);
}

static BOOL new_expHelper_isHomeFeed(id self, SEL _cmd) {
	return sciLiquidGlassButtonsEnabled() ? YES : (orig_expHelper_isHomeFeed ? orig_expHelper_isHomeFeed(self, _cmd) : NO);
}

static BOOL (*orig_IGFloatingTabBarEnabled)(void) = NULL;
static BOOL (*orig_IGTabBarDynamicSizingEnabled)(void) = NULL;
static BOOL (*orig_IGTabBarEnhancedDynamicSizingEnabled)(void) = NULL;
static BOOL (*orig_IGTabBarHomecomingWithFloatingTabEnabled)(void) = NULL;
static BOOL (*orig_IGTabBarViewPointFixEnabled)(void) = NULL;
static NSInteger (*orig_IGTabBarStyleForLauncherSet)(NSInteger) = NULL;

#define SCI_BOOL_FISHHOOK(name) static BOOL hook_##name(void) { return SCI_LG_SURFACES ? YES : (orig_##name ? orig_##name() : NO); }

SCI_BOOL_FISHHOOK(IGFloatingTabBarEnabled)
SCI_BOOL_FISHHOOK(IGTabBarDynamicSizingEnabled)
SCI_BOOL_FISHHOOK(IGTabBarEnhancedDynamicSizingEnabled)
SCI_BOOL_FISHHOOK(IGTabBarHomecomingWithFloatingTabEnabled)
SCI_BOOL_FISHHOOK(IGTabBarViewPointFixEnabled)

static NSInteger hook_IGTabBarStyleForLauncherSet(NSInteger set) {
	return SCI_LG_SURFACES ? 1 : (orig_IGTabBarStyleForLauncherSet ? orig_IGTabBarStyleForLauncherSet(set) : set);
}

static void sciInstallLiquidGlassButtonHooks(void) {
	if (!sciLiquidGlassButtonsEnabled()) return;

	Class swizzleToggle = objc_getClass("IGLiquidGlassSwizzle.IGLiquidGlassSwizzleToggle");

	if (swizzleToggle) {
		MSHookMessageEx(swizzleToggle, @selector(isEnabled), (IMP)new_swizzleToggle_isEnabled, (IMP *)&orig_swizzleToggle_isEnabled);
	}

	Class expHelper = objc_getClass("IGLiquidGlassExperimentHelper.IGLiquidGlassNavigationExperimentHelper");

	if (expHelper) {
		MSHookMessageEx(expHelper, @selector(isEnabled), (IMP)new_expHelper_isEnabled, (IMP *)&orig_expHelper_isEnabled);
		MSHookMessageEx(expHelper, @selector(isHomeFeedHeaderEnabled), (IMP)new_expHelper_isHomeFeed, (IMP *)&orig_expHelper_isHomeFeed);
	}
}

static void sciInstallLiquidGlassSurfaceHooks(void) {
	if (!SCI_LG_SURFACES) return;

	int result = rebind_symbols((struct rebinding[]){
		{"IGFloatingTabBarEnabled", (void *)hook_IGFloatingTabBarEnabled, (void **)&orig_IGFloatingTabBarEnabled},
		{"IGTabBarDynamicSizingEnabled", (void *)hook_IGTabBarDynamicSizingEnabled, (void **)&orig_IGTabBarDynamicSizingEnabled},
		{"IGTabBarEnhancedDynamicSizingEnabled", (void *)hook_IGTabBarEnhancedDynamicSizingEnabled, (void **)&orig_IGTabBarEnhancedDynamicSizingEnabled},
		{"IGTabBarHomecomingWithFloatingTabEnabled", (void *)hook_IGTabBarHomecomingWithFloatingTabEnabled, (void **)&orig_IGTabBarHomecomingWithFloatingTabEnabled},
		{"IGTabBarViewPointFixEnabled", (void *)hook_IGTabBarViewPointFixEnabled, (void **)&orig_IGTabBarViewPointFixEnabled},
		{"IGTabBarStyleForLauncherSet", (void *)hook_IGTabBarStyleForLauncherSet, (void **)&orig_IGTabBarStyleForLauncherSet},
	}, 6);

	NSLog(@"[SCInsta] Liquid glass surfaces fishhook result=%d floating=%p dynamic=%p enhanced=%p homecoming=%p viewpoint=%p style=%p",
		result,
		orig_IGFloatingTabBarEnabled,
		orig_IGTabBarDynamicSizingEnabled,
		orig_IGTabBarEnhancedDynamicSizingEnabled,
		orig_IGTabBarHomecomingWithFloatingTabEnabled,
		orig_IGTabBarViewPointFixEnabled,
		orig_IGTabBarStyleForLauncherSet
	);
}

%ctor {
	SCIRegisterDefaultsOnce();

	%init(SCIAppLifecycleGroup);
	%init(SCIDebugBlockGroup);
	%init(SCIScreenshotBlockGroup);
	%init(SCIHideItemsGroup);
	%init(SCIConfirmActionsGroup);
	%init(SCISafeModeGroup);

	if (sciFlexEnabled()) {%init(SCIFlexGroup);}

	if (sciLiquidGlassButtonsEnabled()) {
		%init(SCILiquidGlassButtonsGroup);
		sciInstallLiquidGlassButtonHooks();
	}

	sciInstallLiquidGlassSurfaceHooks();

	if (SCI_PREF(@"liquid_glass_buttons") && !sciSupportsLiquidGlassButtons()) {
		NSLog(@"[SCInsta] liquid_glass_buttons disabled on iOS 18 and below");
	}
}
