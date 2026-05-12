// Full profile counts — profile header followers/posts as 11,943 instead of 11.9K.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <substrate.h>

static NSString *sciCountText(NSNumber *number) {
	static NSNumberFormatter *formatter;
	static dispatch_once_t once;

	dispatch_once(&once, ^{
		formatter = [NSNumberFormatter new];
		formatter.numberStyle = NSNumberFormatterDecimalStyle;
		formatter.usesGroupingSeparator = YES;
	});

	return number ? [formatter stringFromNumber:number] : nil;
}

static NSNumber *sciNum(id value) {
	if ([value isKindOfClass:NSNumber.class]) return value;
	if (![value isKindOfClass:NSString.class]) return nil;

	NSString *text = [(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""];
	return text.length ? @(text.longLongValue) : nil;
}

static NSNumber *sciProfileCount(id user, NSDictionary *cache, BOOL posts) {
	return posts
		? (sciNum([user valueForKey:@"mediaCount"]) ?: sciNum([user valueForKey:@"postCount"]) ?: sciNum(cache[@"media_count"]) ?: sciNum(cache[@"post_count"]))
		: (sciNum([user valueForKey:@"followerCount"]) ?: sciNum([user valueForKey:@"followersCount"]) ?: sciNum(cache[@"follower_count"]));
}

static void sciSetText(IGStatButton *button, NSNumber *count) {
	NSString *text = sciCountText(count);
	if (!button || !text.length) return;

	UILabel *label = MSHookIvar<UILabel *>(button, "_countLabel");
	label.text = text;
	[label sizeToFit];
}

%hook _TtC23IGProfileHeaderIdentity38IGProfileHeaderStatButtonContainerView
- (void)layoutSubviews {
	%orig;

	BOOL followers = [SCIUtils getBoolPref:@"full_followers_count"];
	BOOL posts = [SCIUtils getBoolPref:@"full_posts_count"];
	if (!followers && !posts) return;

	IGProfileViewController *vc = (IGProfileViewController *)[SCIUtils nearestViewControllerForView:self];
	id user = [vc user];
	NSDictionary *cache = [SCIUtils fieldCacheForObject:user];

	if (followers) {
		sciSetText(MSHookIvar<IGStatButton *>(self, "$__lazy_storage_$_followersButton"), sciProfileCount(user, cache, NO));
	}

	if (posts) {
		sciSetText(MSHookIvar<IGStatButton *>(self, "postCountButton"), sciProfileCount(user, cache, YES));
	}
}
%end