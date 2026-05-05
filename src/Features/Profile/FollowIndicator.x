// Follow indicator — shows whether the profile user follows you.
// Fetches via /api/v1/friendships/show/{pk}/, renders inside the stats container.

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCIChrome.h"
#import "../../Networking/SCIInstagramAPI.h"
#import <objc/runtime.h>

static const NSInteger kFollowBadgeTag = 99788;
static const char kFollowStatusKey;
static const char kFollowProfilePKKey;
static const char kFollowFetchInFlightKey;

static NSNumber *sciGetFollowStatus(id vc) {
	return objc_getAssociatedObject(vc, &kFollowStatusKey);
}

static void sciSetFollowStatus(id vc, NSNumber *status) {
	objc_setAssociatedObject(vc, &kFollowStatusKey, status, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *sciGetFollowProfilePK(id vc) {
	return objc_getAssociatedObject(vc, &kFollowProfilePKKey);
}

static void sciSetFollowProfilePK(id vc, NSString *pk) {
	objc_setAssociatedObject(vc, &kFollowProfilePKKey, pk, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static NSString *sciGetFetchInFlight(id vc) {
	return objc_getAssociatedObject(vc, &kFollowFetchInFlightKey);
}

static void sciSetFetchInFlight(id vc, NSString *pk) {
	objc_setAssociatedObject(vc, &kFollowFetchInFlightKey, pk, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void sciRemoveBadgeFromView(UIView *view) {
	UIView *old = [view viewWithTag:kFollowBadgeTag];
	if (old) [old removeFromSuperview];
}

static UIView *sciFindStatContainer(UIView *rootView) {
	if (!rootView) return nil;

	NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:rootView];

	while (stack.count) {
		UIView *view = stack.lastObject;
		[stack removeLastObject];

		if ([NSStringFromClass([view class]) containsString:@"StatButtonContainerView"]) {
			return view;
		}

		for (UIView *subview in view.subviews) {
			[stack addObject:subview];
		}
	}

	return nil;
}

static BOOL sciFollowIndicatorEnabled(void) {
	NSString *mode = [SCIUtils getStringPref:@"follow_indicator"];
	return mode.length > 0 && ![mode isEqualToString:@"off"];
}

static BOOL sciFollowIndicatorColored(void) {
	return [[SCIUtils getStringPref:@"follow_indicator"] isEqualToString:@"colored"];
}

static void sciRenderBadge(UIViewController *vc) {
	NSNumber *status = sciGetFollowStatus(vc);
	if (!status) return;

	UIView *statContainer = sciFindStatContainer(vc.view);
	if (!statContainer) return;

	if ([statContainer viewWithTag:kFollowBadgeTag]) return;

	BOOL followedBy = status.boolValue;
	NSString *text = followedBy ? SCILocalized(@"Follows you") : SCILocalized(@"Doesn't follow you");

	SCIChromeLabel *badge = [[SCIChromeLabel alloc] initWithText:text];
	badge.tag = kFollowBadgeTag;
	badge.translatesAutoresizingMaskIntoConstraints = NO;
	badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
	if (sciFollowIndicatorColored()) {
		badge.textColor = followedBy
			? [UIColor colorWithRed:0.3 green:0.75 blue:0.4 alpha:1.0]
			: [UIColor colorWithRed:0.85 green:0.3 blue:0.3 alpha:1.0];
	} else {
		badge.textColor = [UIColor secondaryLabelColor];
	}

	[statContainer addSubview:badge];

	[NSLayoutConstraint activateConstraints:@[
		[badge.leadingAnchor constraintEqualToAnchor:statContainer.leadingAnchor],
		[badge.bottomAnchor constraintEqualToAnchor:statContainer.bottomAnchor constant:-8]
	]];
}

static void sciFetchAndRender(UIViewController *vc, NSString *profilePK);

static void sciRefreshIndicator(UIViewController *vc) {
	if (!sciFollowIndicatorEnabled()) {
		sciRemoveBadgeFromView(vc.view);
		sciSetFollowStatus(vc, nil);
		sciSetFollowProfilePK(vc, nil);
		sciSetFetchInFlight(vc, nil);
		return;
	}

	id igUser = nil;
	@try {
		igUser = [vc valueForKey:@"user"];
	} @catch (__unused NSException *e) {}

	NSString *profilePK = [SCIUtils pkFromIGUser:igUser];
	NSString *myPK = [SCIUtils currentUserPK];

	if (!igUser || !profilePK.length) return;

	if (!myPK.length || [profilePK isEqualToString:myPK]) {
		sciRemoveBadgeFromView(vc.view);
		sciSetFollowStatus(vc, nil);
		sciSetFollowProfilePK(vc, nil);
		sciSetFetchInFlight(vc, nil);
		return;
	}

	NSString *cachedPK = sciGetFollowProfilePK(vc);
	NSNumber *cachedStatus = sciGetFollowStatus(vc);

	if (cachedStatus && [cachedPK isEqualToString:profilePK]) {
		sciRenderBadge(vc);
		return;
	}

	if ([cachedPK isEqualToString:profilePK] && [sciGetFetchInFlight(vc) isEqualToString:profilePK]) return;

	sciRemoveBadgeFromView(vc.view);
	sciSetFollowStatus(vc, nil);
	sciSetFollowProfilePK(vc, profilePK);
	sciFetchAndRender(vc, profilePK);
}

static void sciFetchAndRender(UIViewController *vc, NSString *profilePK) {
	sciSetFetchInFlight(vc, profilePK);
	__weak UIViewController *weakSelf = vc;
	NSString *requestedPK = [profilePK copy];
	NSString *path = [NSString stringWithFormat:@"friendships/show/%@/", requestedPK];

	[SCIInstagramAPI sendRequestWithMethod:@"GET" path:path body:nil completion:^(NSDictionary *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *strongVC = weakSelf;
			if (!strongVC) return;

			if (![sciGetFetchInFlight(strongVC) isEqualToString:requestedPK]) return;
			sciSetFetchInFlight(strongVC, nil);

			if (error || !response) return;

			if (![sciGetFollowProfilePK(strongVC) isEqualToString:requestedPK]) return;

			if (!sciFollowIndicatorEnabled()) {
				sciRemoveBadgeFromView(strongVC.view);
				sciSetFollowStatus(strongVC, nil);
				sciSetFollowProfilePK(strongVC, nil);
				return;
			}

			BOOL followedBy = [response[@"followed_by"] boolValue];
			sciSetFollowStatus(strongVC, @(followedBy));
			sciRenderBadge(strongVC);
		});
	}];
}

%hook IGProfileViewController

- (void)setUser:(id)user {
	%orig;
	dispatch_async(dispatch_get_main_queue(), ^{
		sciRefreshIndicator(self);
	});
}

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	sciRefreshIndicator(self);
}

- (void)viewDidLayoutSubviews {
	%orig;
	if (!sciGetFollowStatus(self)) return;
	UIView *statContainer = sciFindStatContainer(self.view);
	if (statContainer && ![statContainer viewWithTag:kFollowBadgeTag]) {
		sciRenderBadge(self);
	}
}

%end
