// Reels action button — injects a RyukGram action button above the reel's
// vertical like/comment/share sidebar (IGSundialViewerVerticalUFI).

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCIChrome.h"
#import "../../ActionButton/SCIActionButton.h"
#import "../../ActionButton/SCIActionIcon.h"
#import "../../ActionButton/SCIMediaActions.h"

static const NSInteger kReelActionBtnTag = 1337;
static char kReelActionDefaultKey;

static inline BOOL SCIReelsActionEnabled(void) {
	id value = [NSUserDefaults.standardUserDefaults objectForKey:@"reels_action_button"];
	return value ? [value boolValue] : YES;
}

static inline NSString *SCIReelDefaultAction(void) {
	NSString *action = [SCIUtils getStringPref:@"reels_action_default"];
	return action.length ? action : @"menu";
}

static UIView *sciFindSuperviewOfClass(UIView *view, NSString *className) {
	Class cls = NSClassFromString(className);
	if (!view || !cls) return nil;

	UIView *current = view.superview;

	for (int depth = 0; current && depth < 20; depth++) {
		if ([current isKindOfClass:cls]) return current;
		current = current.superview;
	}

	return nil;
}

static id sciFindMediaIvar(UIView *view) {
	if (!view) return nil;

	Class mediaClass = NSClassFromString(@"IGMedia");
	if (!mediaClass) return nil;

	unsigned int count = 0;
	Ivar *ivars = class_copyIvarList(view.class, &count);
	id found = nil;

	for (unsigned int i = 0; i < count; i++) {
		const char *type = ivar_getTypeEncoding(ivars[i]);
		if (!type || type[0] != '@') continue;

		@try {
			id value = object_getIvar(view, ivars[i]);

			if (value && [value isKindOfClass:mediaClass]) {
				found = value;
				break;
			}
		} @catch (__unused id e) {}
	}

	if (ivars) free(ivars);
	return found;
}

static id sciCurrentCarouselChildMedia(UIView *carouselCell, id parentMedia) {
	if (!carouselCell || !parentMedia) return parentMedia;

	NSInteger currentIndex = 0;

	Ivar idxIvar = class_getInstanceVariable(carouselCell.class, "_currentIndex");
	if (idxIvar) {
		currentIndex = *(NSInteger *)((char *)(__bridge void *)carouselCell + ivar_getOffset(idxIvar));
	}

	Ivar fracIvar = class_getInstanceVariable(carouselCell.class, "_currentFractionalIndex");
	if (fracIvar) {
		NSInteger roundedIndex = (NSInteger)round(*(double *)((char *)(__bridge void *)carouselCell + ivar_getOffset(fracIvar)));
		if (roundedIndex > currentIndex) currentIndex = roundedIndex;
	}

	Ivar cvIvar = class_getInstanceVariable(carouselCell.class, "_collectionView");
	if (cvIvar) {
		UICollectionView *collectionView = object_getIvar(carouselCell, cvIvar);
		CGFloat pageWidth = collectionView.bounds.size.width;

		if (collectionView && pageWidth > 0.0) {
			NSInteger collectionIndex = (NSInteger)round(collectionView.contentOffset.x / pageWidth);
			if (collectionIndex > currentIndex) currentIndex = collectionIndex;
		}
	}

	NSArray *children = [SCIMediaActions carouselChildrenForMedia:parentMedia];

	if (currentIndex >= 0 && (NSUInteger)currentIndex < children.count) {
		return children[currentIndex];
	}

	return parentMedia;
}

static id sciReelsMediaProvider(UIView *sourceView) {
	UIView *videoCell = sciFindSuperviewOfClass(sourceView, @"IGSundialViewerVideoCell");
	if (videoCell) {
		id media = sciFindMediaIvar(videoCell);
		if (media) return media;
	}

	UIView *photoCell = sciFindSuperviewOfClass(sourceView, @"IGSundialViewerPhotoCell");
	if (photoCell) {
		id media = sciFindMediaIvar(photoCell);
		if (media) return media;
	}

	UIView *carouselCell = sciFindSuperviewOfClass(sourceView, @"IGSundialViewerCarouselCell");
	if (carouselCell) {
		id parentMedia = sciFindMediaIvar(carouselCell);
		if (parentMedia) return sciCurrentCarouselChildMedia(carouselCell, parentMedia);
	}

	return nil;
}

%hook IGSundialViewerVerticalUFI

- (void)didMoveToSuperview {
	%orig;
	((void(*)(id, SEL))objc_msgSend)(self, @selector(sciReloadReelActionButton));
}

- (void)layoutSubviews {
	%orig;
	((void(*)(id, SEL))objc_msgSend)(self, @selector(sciReloadReelActionButton));
}

%new
- (void)sciReloadReelActionButton {
	if (!self.superview) return;

	SCIChromeButton *button = (SCIChromeButton *)[self viewWithTag:kReelActionBtnTag];
	if (![button isKindOfClass:SCIChromeButton.class]) button = nil;

	if (!SCIReelsActionEnabled()) {
		[button removeFromSuperview];
		return;
	}

	NSString *currentAction = SCIReelDefaultAction();
	NSString *configuredAction = objc_getAssociatedObject(button, &kReelActionDefaultKey);

	if (button && configuredAction && ![configuredAction isEqualToString:currentAction]) {
		[button removeFromSuperview];
		button = nil;
	}

	if (!button) {
		button = [[SCIChromeButton alloc] initWithSymbol:@"" pointSize:0 diameter:40];
		button.tag = kReelActionBtnTag;
		button.bubbleColor = UIColor.clearColor;
		button.adjustsImageWhenHighlighted = NO;

		UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
		config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
		config.background.backgroundColor = UIColor.clearColor;
		config.contentInsets = NSDirectionalEdgeInsetsZero;
		button.configuration = config;

		self.clipsToBounds = NO;
		[self addSubview:button];

		[NSLayoutConstraint activateConstraints:@[
			[button.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
			[button.bottomAnchor constraintEqualToAnchor:self.topAnchor constant:-10.0],
			[button.widthAnchor constraintEqualToConstant:40.0],
			[button.heightAnchor constraintEqualToConstant:40.0]
		]];

		[SCIActionButton configureButton:button
								 context:SCIActionContextReels
								 prefKey:@"reels_action_default"
						   mediaProvider:^id (UIView *sourceView) {
			return sciReelsMediaProvider(sourceView);
		}];

		[SCIActionIcon attachAutoUpdate:button pointSize:24 style:SCIActionIconStyleShadowBaked];

		objc_setAssociatedObject(button, &kReelActionDefaultKey, currentAction, OBJC_ASSOCIATION_COPY_NONATOMIC);
	}
}

%end