// IG's main app re-adds every APNs-delivered push as a local notification, so
// the user sees the appex's banner AND a second one from -addNotificationRequest:.
// Push-derived adds always carry `gid` (IG server-generated push ID) in the
// userInfo — local notifs never do. Suppress those; the appex's banner stands.

#import "../../Utils.h"
#import <UserNotifications/UserNotifications.h>

%hook UNUserNotificationCenter
- (void)addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(void (^)(NSError *error))completionHandler {
	if (![SCIUtils getBoolPref:@"sci_fix_duplicate_notifications"]) { %orig; return; }

	NSDictionary *userInfo = request.content.userInfo;
	BOOL isPushDerived = [userInfo isKindOfClass:[NSDictionary class]] &&
		(userInfo[@"gid"] != nil || userInfo[@"aps"] != nil);

	if (isPushDerived) {
		if (completionHandler) completionHandler(nil);
		return;
	}
	%orig;
}
%end
