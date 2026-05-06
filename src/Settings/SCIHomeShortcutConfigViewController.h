// Settings sub-page for the home top-bar shortcut button.
//
// Layout mirrors the action-button menu config screen: one Behavior section
// at the top, one Actions section below with drag-to-reorder rows + per-row
// enable toggles. Persistence is an ordered NSArray<NSDictionary> under the
// `home_shortcut_actions` pref.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIHomeShortcutConfigViewController : UITableViewController
@end

NS_ASSUME_NONNULL_END
