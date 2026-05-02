// DM disappearing-media overlay buttons — action / eye / audio (tags 1342–1344).
// Hooks IGDirectVisualMessageViewerController directly; reads only dm_visual_* prefs.
// Action button defaults to enabled when dm_visual_action_button key does not exist.

#import "OverlayHelpers.h"
#import "../../SCIChrome.h"
#import "../../ActionButton/SCIMediaViewer.h"

// Per-button weak ref to the owning DM VC so handlers skip the responder walk.
static const void *kSCIDMOwnerVCKey = &kSCIDMOwnerVCKey;
static char kDMActionDefaultKey;

static inline BOOL SCIDMPrefBoolDefault(NSString *key, BOOL defaultValue) {
	id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
	return value ? [value boolValue] : defaultValue;
}

static inline BOOL SCIDMActionEnabled(void) {return SCIDMPrefBoolDefault(@"dm_visual_action_button", YES);}

static inline BOOL SCIDMEyeEnabled(void) {return [SCIUtils getBoolPref:@"dm_visual_seen_button"];}

static inline NSString *SCIDMDefaultAction(void) {
	NSString *action = [SCIUtils getStringPref:@"dm_visual_action_default"];
	return action.length ? action : @"menu";
}

static inline NSString *SCIDMActionSymbol(void) {return [SCIDMDefaultAction() isEqualToString:@"download_photos"] ? @"arrow.down.to.line.circle.fill" : @"ellipsis.circle";}

static inline SCIChromeButton *SCIDMButton(NSString *symbol, CGFloat pointSize, CGFloat diameter, NSInteger tag) {
	SCIChromeButton *button = [[SCIChromeButton alloc] initWithSymbol:symbol pointSize:pointSize diameter:diameter];
	button.tag = tag;
	return button;
}

static inline void SCIDMRemoveButton(UIView *overlay, NSInteger tag) {
	[[overlay viewWithTag:tag] removeFromSuperview];
}

// MARK: - Menu item builders

static NSArray<UIMenuElement *> *sciDMActionMenuItems(UIViewController *dmVC, UIView *sourceView) {
	__weak UIView *weakSource = sourceView;

	return @[
		[UIAction actionWithTitle:SCILocalized(@"Expand") image:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"] identifier:nil handler:^(__unused UIAction *a) {
			sciDMExpandMedia(dmVC);
		}],
		[UIAction actionWithTitle:SCILocalized(@"Messages settings") image:[UIImage systemImageNamed:@"gearshape"] identifier:nil handler:^(__unused UIAction *a) {
			sciOpenMessagesSettings(weakSource);
		}],
		[UIAction actionWithTitle:SCILocalized(@"Download and share") image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(__unused UIAction *a) {
			sciDMShareMedia(dmVC);
		}],
		[UIAction actionWithTitle:SCILocalized(@"Download to Photos") image:[UIImage systemImageNamed:@"square.and.arrow.down"] identifier:nil handler:^(__unused UIAction *a) {
			sciDMDownloadMedia(dmVC);
		}]
	];
}

static NSArray<UIMenuElement *> *sciDMEyeMenuItems(UIViewController *dmVC, UIView *sourceView) {
	__weak UIView *weakSource = sourceView;

	return @[
		[UIAction actionWithTitle:SCILocalized(@"Mark as viewed") image:[UIImage systemImageNamed:@"eye"] identifier:nil handler:^(__unused UIAction *a) {
			sciDMMarkCurrentAsViewed(dmVC);
		}],
		[UIAction actionWithTitle:SCILocalized(@"Messages settings") image:[UIImage systemImageNamed:@"gearshape"] identifier:nil handler:^(__unused UIAction *a) {
			sciOpenMessagesSettings(weakSource);
		}]
	];
}

static void sciDMApplyTapMenu(UIButton *button, __weak UIViewController *weakDMVC) {
	__weak UIButton *weakButton = button;

	UIDeferredMenuElement *deferred = [UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> * _Nonnull)) {
		UIViewController *dmVC = weakDMVC;
		UIButton *strongButton = weakButton;

		if (!dmVC || !strongButton) {
			completion(@[]);
			return;
		}

		completion(sciDMActionMenuItems(dmVC, strongButton));
	}];

	button.menu = [UIMenu menuWithChildren:@[deferred]];
	button.showsMenuAsPrimaryAction = YES;
}

// MARK: - Button delegate

@interface SCIDMButtonDelegate : NSObject
+ (instancetype)shared;
- (void)actionTapped:(UIButton *)sender;
- (void)eyeTapped:(UIButton *)sender;
- (void)audioTapped:(SCIChromeButton *)sender;
@end

@implementation SCIDMButtonDelegate

+ (instancetype)shared {
	static SCIDMButtonDelegate *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [SCIDMButtonDelegate new];
	});
	return shared;
}

- (UIViewController *)ownerForButton:(UIView *)button {
	return objc_getAssociatedObject(button, kSCIDMOwnerVCKey);
}

// Default-tap path when pref is not "menu".
- (void)actionTapped:(UIButton *)sender {
	UIViewController *dmVC = [self ownerForButton:sender];
	if (!dmVC) return;

	NSString *tap = SCIDMDefaultAction();

	if ([tap isEqualToString:@"expand"]) {
		sciDMExpandMedia(dmVC);
	} else if ([tap isEqualToString:@"download_share"]) {
		sciDMShareMedia(dmVC);
	} else if ([tap isEqualToString:@"download_photos"]) {
		sciDMDownloadMedia(dmVC);
	}
}

- (void)eyeTapped:(UIButton *)sender {
	UIViewController *dmVC = [self ownerForButton:sender];
	if (!dmVC) return;

	UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
	[haptic impactOccurred];

	[UIView animateWithDuration:0.1 animations:^{
		sender.transform = CGAffineTransformMakeScale(0.8, 0.8);
		sender.alpha = 0.6;
	} completion:^(__unused BOOL finished) {
		[UIView animateWithDuration:0.15 animations:^{
			sender.transform = CGAffineTransformIdentity;
			sender.alpha = 1.0;
		}];
	}];

	sciDMMarkCurrentAsViewed(dmVC);
}

- (void)audioTapped:(SCIChromeButton *)sender {
	UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
	[haptic impactOccurred];

	sciToggleStoryAudio();
	sender.symbolName = sciIsStoryAudioEnabled() ? @"speaker.wave.2" : @"speaker.slash";
}

@end

// MARK: - Long-press menu builder

// UIButton.menu + showsMenuAsPrimaryAction=NO means:
// tap fires default action, long-press shows menu.
static void sciDMAttachLongPressMenu(SCIChromeButton *button, NSInteger tag) {
	__weak SCIChromeButton *weakButton = button;

	UIDeferredMenuElement *deferred = [UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> * _Nonnull)) {
		SCIChromeButton *strongButton = weakButton;
		UIViewController *dmVC = strongButton ? objc_getAssociatedObject(strongButton, kSCIDMOwnerVCKey) : nil;

		if (!dmVC) {
			completion(@[]);
			return;
		}

		completion(tag == SCI_DM_ACTION_TAG ? sciDMActionMenuItems(dmVC, strongButton) : sciDMEyeMenuItems(dmVC, strongButton));
	}];

	button.menu = [UIMenu menuWithChildren:@[deferred]];
	button.showsMenuAsPrimaryAction = NO;
}

static void sciDMConfigureActionButton(SCIChromeButton *button, UIViewController *dmVC) {
	if (!button || !dmVC) return;

	SCIDMButtonDelegate *delegate = SCIDMButtonDelegate.shared;
	NSString *action = SCIDMDefaultAction();

	button.symbolName = SCIDMActionSymbol();
	button.menu = nil;
	button.showsMenuAsPrimaryAction = NO;

	[button removeTarget:delegate action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];

	if ([action isEqualToString:@"menu"]) {
		sciDMApplyTapMenu(button, dmVC);
	} else {
		// Tap = default action, long-press = full menu.
		[button addTarget:delegate action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];
		sciDMAttachLongPressMenu(button, SCI_DM_ACTION_TAG);
	}

	objc_setAssociatedObject(button, &kDMActionDefaultKey, action, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void sciDMRefreshActionIcon(UIViewController *dmVC) {
	if (!dmVC || !dmVC.isViewLoaded) return;

	UIView *overlay = sciFindOverlayInView(dmVC.view);
	SCIChromeButton *button = (SCIChromeButton *)[overlay viewWithTag:SCI_DM_ACTION_TAG];

	if (![button isKindOfClass:SCIChromeButton.class]) return;

	NSString *action = SCIDMDefaultAction();
	NSString *oldAction = objc_getAssociatedObject(button, &kDMActionDefaultKey);

	if (!oldAction || ![oldAction isEqualToString:action]) {
		sciDMConfigureActionButton(button, dmVC);
		return;
	}

	NSString *symbol = SCIDMActionSymbol();

	if (![button.symbolName isEqualToString:symbol]) {
		button.symbolName = symbol;
	}
}

// MARK: - Overlay injection

static void sciDMInstallButtons(UIViewController *dmVC) {
	if (!dmVC || !dmVC.isViewLoaded) return;

	UIView *overlay = sciFindOverlayInView(dmVC.view);
	if (!overlay) return;

	// Kill any story-tag injections from the shared story overlay hook.
	SCIDMRemoveButton(overlay, SCI_STORY_ACTION_TAG);
	SCIDMRemoveButton(overlay, SCI_STORY_EYE_TAG);
	SCIDMRemoveButton(overlay, SCI_STORY_AUDIO_TAG);

	SCIDMButtonDelegate *delegate = SCIDMButtonDelegate.shared;

	// --- Action button (tag 1342) ---
	SCIDMRemoveButton(overlay, SCI_DM_ACTION_TAG);

	if (SCIDMActionEnabled()) {
		SCIChromeButton *button = SCIDMButton(SCIDMActionSymbol(), 18.0, 36.0, SCI_DM_ACTION_TAG);
		objc_setAssociatedObject(button, kSCIDMOwnerVCKey, dmVC, OBJC_ASSOCIATION_ASSIGN);

		[overlay addSubview:button];

		[NSLayoutConstraint activateConstraints:@[
			[button.bottomAnchor constraintEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-100.0],
			[button.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-12.0],
			[button.widthAnchor constraintEqualToConstant:36.0],
			[button.heightAnchor constraintEqualToConstant:36.0]
		]];

		sciDMConfigureActionButton(button, dmVC);
	}

	// --- Eye / mark-as-viewed (tag 1343) ---
	SCIDMRemoveButton(overlay, SCI_DM_EYE_TAG);

	if (SCIDMEyeEnabled()) {
		SCIChromeButton *button = SCIDMButton(@"eye", 18.0, 36.0, SCI_DM_EYE_TAG);
		objc_setAssociatedObject(button, kSCIDMOwnerVCKey, dmVC, OBJC_ASSOCIATION_ASSIGN);

		[button addTarget:delegate action:@selector(eyeTapped:) forControlEvents:UIControlEventTouchUpInside];
		sciDMAttachLongPressMenu(button, SCI_DM_EYE_TAG);

		[overlay addSubview:button];

		UIView *anchor = [overlay viewWithTag:SCI_DM_ACTION_TAG];

		if (anchor) {
			[NSLayoutConstraint activateConstraints:@[
				[button.centerYAnchor constraintEqualToAnchor:anchor.centerYAnchor],
				[button.trailingAnchor constraintEqualToAnchor:anchor.leadingAnchor constant:-10.0],
				[button.widthAnchor constraintEqualToConstant:36.0],
				[button.heightAnchor constraintEqualToConstant:36.0]
			]];
		} else {
			[NSLayoutConstraint activateConstraints:@[
				[button.bottomAnchor constraintEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-100.0],
				[button.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-12.0],
				[button.widthAnchor constraintEqualToConstant:36.0],
				[button.heightAnchor constraintEqualToConstant:36.0]
			]];
		}
	}

	// --- Audio toggle (tag 1344) ---
	SCIDMRemoveButton(overlay, SCI_DM_AUDIO_TAG);

	sciInitStoryAudioState();

	if ([SCIUtils getBoolPref:@"dm_visual_audio_toggle"]) {
		NSString *symbol = sciIsStoryAudioEnabled() ? @"speaker.wave.2" : @"speaker.slash";
		SCIChromeButton *button = SCIDMButton(symbol, 14.0, 28.0, SCI_DM_AUDIO_TAG);

		[button addTarget:delegate action:@selector(audioTapped:) forControlEvents:UIControlEventTouchUpInside];

		[overlay addSubview:button];

		[NSLayoutConstraint activateConstraints:@[
			[button.bottomAnchor constraintEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-100.0],
			[button.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:12.0],
			[button.widthAnchor constraintEqualToConstant:28.0],
			[button.heightAnchor constraintEqualToConstant:28.0]
		]];
	}
}

// Rebuild only when an enabled button is missing.
// Action default only refreshes the action icon/behavior.
static void sciDMEnsureButtons(UIViewController *dmVC) {
	if (!dmVC || !dmVC.isViewLoaded) return;

	UIView *overlay = sciFindOverlayInView(dmVC.view);
	if (!overlay) return;

	SCIDMRemoveButton(overlay, SCI_STORY_ACTION_TAG);
	SCIDMRemoveButton(overlay, SCI_STORY_EYE_TAG);
	SCIDMRemoveButton(overlay, SCI_STORY_AUDIO_TAG);

	BOOL needAction = SCIDMActionEnabled() && ![overlay viewWithTag:SCI_DM_ACTION_TAG];
	BOOL needEye = SCIDMEyeEnabled() && ![overlay viewWithTag:SCI_DM_EYE_TAG];
	BOOL needAudio = [SCIUtils getBoolPref:@"dm_visual_audio_toggle"] && ![overlay viewWithTag:SCI_DM_AUDIO_TAG];

	if (needAction || needEye || needAudio) {
		sciDMInstallButtons(dmVC);
		return;
	}

	sciDMRefreshActionIcon(dmVC);
}

// MARK: - VC hook

%group DMOverlayGroup

%hook IGDirectVisualMessageViewerController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	sciDMInstallButtons(self);
}

- (void)viewDidLayoutSubviews {
	%orig;
	sciDMEnsureButtons(self);
}

- (void)viewWillDisappear:(BOOL)animated {
	%orig;

	if (!self.isViewLoaded) return;

	UIView *overlay = sciFindOverlayInView(self.view);
	if (!overlay) return;

	SCIDMRemoveButton(overlay, SCI_DM_ACTION_TAG);
	SCIDMRemoveButton(overlay, SCI_DM_EYE_TAG);
	SCIDMRemoveButton(overlay, SCI_DM_AUDIO_TAG);
}

%end

%end // DMOverlayGroup

%ctor {
	if (SCIDMActionEnabled() ||
		SCIDMEyeEnabled() ||
		[SCIUtils getBoolPref:@"dm_visual_audio_toggle"]) {
		%init(DMOverlayGroup);
	}
}