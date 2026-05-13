// Follow indicator — shows whether the profile user follows you.
// Fetches once per profile PK, renders directly inside the stats container.

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCIChrome.h"
#import "../../Networking/SCIInstagramAPI.h"
#import <objc/runtime.h>

static const NSInteger kFollowBadgeTag = 99788;

static const char kFollowStatusKey;
static const char kFollowProfilePKKey;
static const char kFollowFetchInFlightKey;

static NSMutableDictionary<NSString *, NSNumber *> *sciFollowCache(void) {
	static NSMutableDictionary *cache;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [NSMutableDictionary dictionary];
	});
	return cache;
}

static inline NSString *sciFollowMode(void) {
	return [SCIUtils getStringPref:@"follow_indicator"];
}

static inline BOOL sciFollowIndicatorEnabled(void) {
	NSString *mode = sciFollowMode();
	return mode.length && ![mode isEqualToString:@"off"];
}

static inline BOOL sciFollowIndicatorColored(void) {
	return [sciFollowMode() isEqualToString:@"colored"];
}

static NSNumber *sciFollowStatus(id vc) {
	return objc_getAssociatedObject(vc, &kFollowStatusKey);
}

static void sciSetFollowStatus(id vc, NSNumber *status) {
	objc_setAssociatedObject(vc, &kFollowStatusKey, status, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *sciFollowProfilePK(id vc) {
	return objc_getAssociatedObject(vc, &kFollowProfilePKKey);
}

static void sciSetFollowProfilePK(id vc, NSString *pk) {
	objc_setAssociatedObject(vc, &kFollowProfilePKKey, pk, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static NSString *sciFollowFetchPK(id vc) {
	return objc_getAssociatedObject(vc, &kFollowFetchInFlightKey);
}

static void sciSetFollowFetchPK(id vc, NSString *pk) {
	objc_setAssociatedObject(vc, &kFollowFetchInFlightKey, pk, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void sciRemoveFollowBadge(UIView *root) {
	[[root viewWithTag:kFollowBadgeTag] removeFromSuperview];
}

static void sciResetFollowState(UIViewController *vc) {
	sciRemoveFollowBadge(vc.view);
	sciSetFollowStatus(vc, nil);
	sciSetFollowProfilePK(vc, nil);
	sciSetFollowFetchPK(vc, nil);
}

static id sciProfileUser(UIViewController *vc) {
	@try {
		return [vc valueForKey:@"user"];
	} @catch (__unused id e) {
		return nil;
	}
}

static NSString *sciProfilePK(UIViewController *vc) {
	return [SCIUtils pkFromIGUser:sciProfileUser(vc)];
}

static void sciRenderFollowBadge(UIViewController *vc, UIView *statContainer) {
	NSNumber *status = sciFollowStatus(vc);

	if (!sciFollowIndicatorEnabled() || !status) {
		sciRemoveFollowBadge(statContainer);
		return;
	}

	BOOL followedBy = status.boolValue;
	NSString *text = followedBy ? SCILocalized(@"Follows you") : SCILocalized(@"Doesn't follow you");

	SCIChromeLabel *badge = (SCIChromeLabel *)[statContainer viewWithTag:kFollowBadgeTag];

	if (!badge) {
		badge = [[SCIChromeLabel alloc] initWithText:text];
		badge.tag = kFollowBadgeTag;
		badge.translatesAutoresizingMaskIntoConstraints = NO;
		badge.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];

		[statContainer addSubview:badge];

		[NSLayoutConstraint activateConstraints:@[
			[badge.leadingAnchor constraintEqualToAnchor:statContainer.leadingAnchor],
			[badge.bottomAnchor constraintEqualToAnchor:statContainer.bottomAnchor constant:-8.0]
		]];
	} else {
		badge.text = text;
	}

	badge.textColor = sciFollowIndicatorColored()
		? (followedBy ? [UIColor colorWithRed:0.3 green:0.75 blue:0.4 alpha:1.0] : [UIColor colorWithRed:0.85 green:0.3 blue:0.3 alpha:1.0])
		: UIColor.secondaryLabelColor;
}

static void sciFetchFollowStatus(UIViewController *vc, NSString *profilePK) {
	sciSetFollowFetchPK(vc, profilePK);

	__weak UIViewController *weakVC = vc;
	NSString *requestedPK = profilePK.copy;
	NSString *path = [NSString stringWithFormat:@"friendships/show/%@/", requestedPK];

	[SCIInstagramAPI sendRequestWithMethod:@"GET" path:path body:nil completion:^(NSDictionary *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *strongVC = weakVC;
			if (!strongVC) return;

			if (![sciFollowFetchPK(strongVC) isEqualToString:requestedPK]) return;
			sciSetFollowFetchPK(strongVC, nil);

			if (error || !response || ![sciFollowProfilePK(strongVC) isEqualToString:requestedPK]) return;

			NSNumber *status = @([response[@"followed_by"] boolValue]);
			sciFollowCache()[requestedPK] = status;
			sciSetFollowStatus(strongVC, status);
		});
	}];
}

static void sciRefreshFollowIndicator(UIViewController *vc) {
	if (!sciFollowIndicatorEnabled()) {
		sciResetFollowState(vc);
		return;
	}

	NSString *profilePK = sciProfilePK(vc);
	NSString *myPK = [SCIUtils currentUserPK];

	if (!profilePK.length || !myPK.length || [profilePK isEqualToString:myPK]) {
		sciResetFollowState(vc);
		return;
	}

	if ([sciFollowProfilePK(vc) isEqualToString:profilePK] && sciFollowStatus(vc)) return;

	sciRemoveFollowBadge(vc.view);
	sciSetFollowProfilePK(vc, profilePK);
	sciSetFollowStatus(vc, nil);

	NSNumber *cached = sciFollowCache()[profilePK];

	if (cached) {
		sciSetFollowStatus(vc, cached);
		return;
	}

	if (![sciFollowFetchPK(vc) isEqualToString:profilePK]) {
		sciFetchFollowStatus(vc, profilePK);
	}
}

%hook IGProfileViewController

- (void)setUser:(id)user {
	%orig;
	dispatch_async(dispatch_get_main_queue(), ^{
		sciRefreshFollowIndicator(self);
	});
}

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	sciRefreshFollowIndicator(self);
}

%end

%hook _TtC23IGProfileHeaderIdentity38IGProfileHeaderStatButtonContainerView

- (void)layoutSubviews {
	%orig;

	UIViewController *vc = [SCIUtils nearestViewControllerForView:(UIView *)self];

	if ([vc isKindOfClass:%c(IGProfileViewController)]) {
		sciRenderFollowBadge(vc, (UIView *)self);
	}
}

%end