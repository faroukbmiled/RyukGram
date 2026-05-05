// Feed action button — hooks IGUFIInteractionCountsView.
// Media lives on sibling cells in the same collection view section,
// not directly on the UFI cell itself.

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCIChrome.h"
#import "../../ActionButton/SCIActionButton.h"
#import "../../ActionButton/SCIActionIcon.h"
#import "../../ActionButton/SCIMediaActions.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const NSInteger kFeedActionBtnTag = 13370;
static const void *kFeedPageIndexKey = &kFeedPageIndexKey;
static char kFeedActionConfiguredKey;

static inline BOOL SCIFeedActionEnabled(void) {
	return [SCIUtils getBoolPref:@"feed_action_button"];
}

static inline NSString *SCIFeedDefaultAction(void) {
	return [SCIUtils getStringPref:@"feed_action_default"];
}

static BOOL sciFindFeedUFIContext(UIView *view, UICollectionViewCell **outUFICell, UICollectionView **outCollectionView) {
	UICollectionViewCell *ufiCell = nil;
	UICollectionView *collectionView = nil;

	for (UIView *current = view; current; current = current.superview) {
		if (!ufiCell &&
			[current isKindOfClass:UICollectionViewCell.class] &&
			[NSStringFromClass(current.class) containsString:@"UFI"]) {
			ufiCell = (UICollectionViewCell *)current;
		}

		if ([current isKindOfClass:UICollectionView.class]) {
			collectionView = (UICollectionView *)current;
			break;
		}
	}

	if (outUFICell) *outUFICell = ufiCell;
	if (outCollectionView) *outCollectionView = collectionView;

	return ufiCell && collectionView;
}

// Current carousel page index. Returns -1 if not found.
static NSInteger sciFeedCarouselPageIndex(UIView *button) {
	UICollectionViewCell *ufiCell = nil;
	UICollectionView *collectionView = nil;

	if (!sciFindFeedUFIContext(button, &ufiCell, &collectionView)) return -1;

	NSIndexPath *ufiPath = [collectionView indexPathForCell:ufiCell];
	if (!ufiPath) return -1;

	Class pageMediaClass = NSClassFromString(@"IGPageMediaView");

	for (UICollectionViewCell *cell in collectionView.visibleCells) {
		NSIndexPath *path = [collectionView indexPathForCell:cell];
		if (!path || path.section != ufiPath.section) continue;

		NSString *className = NSStringFromClass(cell.class);
		if (![className containsString:@"Page"]) continue;

		if (pageMediaClass) {
			NSMutableArray *queue = [NSMutableArray arrayWithObject:cell];

			for (NSInteger scanned = 0; queue.count && scanned < 50; scanned++) {
				UIView *current = queue.firstObject;
				[queue removeObjectAtIndex:0];

				if ([current isKindOfClass:pageMediaClass] &&
					[current respondsToSelector:@selector(currentMediaItem)] &&
					[current respondsToSelector:@selector(items)]) {
					@try {
						id currentItem = ((id(*)(id, SEL))objc_msgSend)(current, @selector(currentMediaItem));
						NSArray *items = ((id(*)(id, SEL))objc_msgSend)(current, @selector(items));

						if (currentItem && items.count) {
							NSUInteger index = [items indexOfObjectIdenticalTo:currentItem];
							if (index != NSNotFound) return (NSInteger)index;
						}
					} @catch (__unused id e) {}
				}

				for (UIView *subview in current.subviews) {
					[queue addObject:subview];
				}
			}
		}

		for (NSString *ivarName in @[@"_currentIndex", @"_currentPage", @"_currentMediaIndex"]) {
			Ivar ivar = class_getInstanceVariable(cell.class, ivarName.UTF8String);

			if (ivar) {
				return *(NSInteger *)((char *)(__bridge void *)cell + ivar_getOffset(ivar));
			}
		}

		NSMutableArray *queue = [NSMutableArray arrayWithObject:cell];

		for (NSInteger scanned = 0; queue.count && scanned < 80; scanned++) {
			UIView *current = queue.firstObject;
			[queue removeObjectAtIndex:0];

			if ([current isKindOfClass:UIScrollView.class] && current != collectionView) {
				UIScrollView *scrollView = (UIScrollView *)current;
				CGFloat pageWidth = scrollView.bounds.size.width;

				if (pageWidth > 100.0 && scrollView.contentSize.width > pageWidth * 1.5) {
					return (NSInteger)round(scrollView.contentOffset.x / pageWidth);
				}
			}

			for (UIView *subview in current.subviews) {
				[queue addObject:subview];
			}
		}
	}

	return -1;
}

// Extract IGMedia from sibling cells in the same collection view section.
static IGMedia *sciFeedMediaFromButton(UIView *button) {
	if (!button || !button.window) return nil;

	Class mediaClass = NSClassFromString(@"IGMedia");
	if (!mediaClass) return nil;

	UICollectionViewCell *ufiCell = nil;
	UICollectionView *collectionView = nil;

	if (!sciFindFeedUFIContext(button, &ufiCell, &collectionView)) return nil;

	NSIndexPath *ufiPath = [collectionView indexPathForCell:ufiCell];
	if (!ufiPath) return nil;

	for (UICollectionViewCell *cell in collectionView.visibleCells) {
		NSIndexPath *path = [collectionView indexPathForCell:cell];
		if (!path || path.section != ufiPath.section || cell == ufiCell) continue;

		NSString *className = NSStringFromClass(cell.class);
		if (![className containsString:@"Photo"] &&
			![className containsString:@"Video"] &&
			![className containsString:@"Media"] &&
			![className containsString:@"Page"]) {
			continue;
		}

		if ([cell respondsToSelector:@selector(mediaCellFeedItem)]) {
			@try {
				id media = ((id(*)(id, SEL))objc_msgSend)(cell, @selector(mediaCellFeedItem));
				if (media && [media isKindOfClass:mediaClass]) return (IGMedia *)media;
			} @catch (__unused id e) {}
		}

		for (Class cls = object_getClass(cell); cls && cls != UICollectionViewCell.class; cls = class_getSuperclass(cls)) {
			unsigned int count = 0;
			Ivar *ivars = class_copyIvarList(cls, &count);

			for (unsigned int i = 0; i < count; i++) {
				const char *type = ivar_getTypeEncoding(ivars[i]);
				if (!type || type[0] != '@') continue;

				@try {
					id value = object_getIvar(cell, ivars[i]);

					if (value && [value isKindOfClass:mediaClass]) {
						if (ivars) free(ivars);
						return (IGMedia *)value;
					}

					if (value && [value respondsToSelector:@selector(media)]) {
						id media = ((id(*)(id, SEL))objc_msgSend)(value, @selector(media));

						if (media && [media isKindOfClass:mediaClass]) {
							if (ivars) free(ivars);
							return (IGMedia *)media;
						}
					}
				} @catch (__unused id e) {}
			}

			if (ivars) free(ivars);
		}
	}

	return nil;
}

static void sciResetFeedActionButton(SCIChromeButton *button) {
	[button removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
	button.menu = nil;
	button.showsMenuAsPrimaryAction = NO;
}

static void sciConfigureFeedActionButton(SCIChromeButton *button) {
	sciResetFeedActionButton(button);

	[SCIActionButton configureButton:button
							 context:SCIActionContextFeed
							 prefKey:@"feed_action_default"
					   mediaProvider:^id (UIView *sourceView) {
		id parentMedia = sciFeedMediaFromButton(sourceView);
		if (!parentMedia) return nil;

		if ([SCIMediaActions isCarouselMedia:parentMedia]) {
			NSInteger index = sciFeedCarouselPageIndex(sourceView);
			NSArray *children = [SCIMediaActions carouselChildrenForMedia:parentMedia];

			if (index >= 0 && (NSUInteger)index < children.count) {
				objc_setAssociatedObject(sourceView, kFeedPageIndexKey, @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
				return children[index];
			}
		}

		return parentMedia;
	}];
}

%hook IGUFIInteractionCountsView

- (void)updateUFIWithButtonsConfig:(id)config interactionCountProvider:(id)provider {
	%orig;

	SCIChromeButton *button = (SCIChromeButton *)[self viewWithTag:kFeedActionBtnTag];

	if (![button isKindOfClass:SCIChromeButton.class]) {
		button = nil;
	}

	if (!SCIFeedActionEnabled()) {
		[button removeFromSuperview];
		return;
	}

	if (!button) {
		button = [[SCIChromeButton alloc] initWithSymbol:@"" pointSize:21.0 diameter:36.0];
		button.tag = kFeedActionBtnTag;
		button.iconTint = UIColor.labelColor;
		button.bubbleColor = UIColor.clearColor;
		button.adjustsImageWhenHighlighted = NO;

		[self addSubview:button];

		// Position: right side, left of bookmark. Shifted up to align
		// with native like/comment/share icons.
		[NSLayoutConstraint activateConstraints:@[
			[button.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-44.0],
			[button.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-6.0],
			[button.widthAnchor constraintEqualToConstant:36.0],
			[button.heightAnchor constraintEqualToConstant:36.0]
		]];

		[SCIActionIcon attachAutoUpdate:button pointSize:21.0 style:SCIActionIconStylePlain];
	}

	NSString *action = SCIFeedDefaultAction();
	NSString *configuredAction = objc_getAssociatedObject(button, &kFeedActionConfiguredKey);

	if (!configuredAction || ![configuredAction isEqualToString:action]) {
		sciConfigureFeedActionButton(button);
		objc_setAssociatedObject(button, &kFeedActionConfiguredKey, action, OBJC_ASSOCIATION_COPY_NONATOMIC);
	}
}

%end