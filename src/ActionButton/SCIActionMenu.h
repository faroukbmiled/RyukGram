// SCIActionMenu — reusable action menu model + UIMenu builder.

#import <UIKit/UIKit.h>

@class SCIActionMenuConfig;
@class SCIActionConfigSection;

NS_ASSUME_NONNULL_BEGIN

/// One menu entry. Either a leaf (has handler) or a submenu (has children).
@interface SCIAction : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *subtitle;
@property (nonatomic, copy, readonly, nullable) NSString *systemIconName;
@property (nonatomic, copy, readonly, nullable) void (^handler)(void);
@property (nonatomic, copy, readonly, nullable) NSArray<SCIAction *> *children;
@property (nonatomic, assign, readonly) BOOL destructive;
@property (nonatomic, assign, readonly) BOOL isSeparator;
@property (nonatomic, assign, readonly) BOOL disabled;
/// Optional stable identifier (matches SCIActionCatalog action IDs). Used to
/// look up an action's handler from a freshly built menu without depending on
/// localized titles.
@property (nonatomic, copy, nullable) NSString *actionID;

+ (instancetype)actionWithTitle:(NSString *)title
                           icon:(nullable NSString *)icon
                        handler:(void(^)(void))handler;

/// When placed first in the actions array, renders as a small grey caption above the menu.
+ (instancetype)headerWithTitle:(NSString *)title;

+ (instancetype)actionWithTitle:(NSString *)title
                       subtitle:(nullable NSString *)subtitle
                           icon:(nullable NSString *)icon
                    destructive:(BOOL)destructive
                        handler:(void(^)(void))handler;

+ (instancetype)actionWithTitle:(NSString *)title
                           icon:(nullable NSString *)icon
                       children:(NSArray<SCIAction *> *)children;

/// A visual group break. Rendered as an inline submenu divider in UIMenu.
+ (instancetype)separator;

/// Read-only data row — rendered greyed out, non-tappable. Use for showing
/// values inside an action menu that are visual context, not commands.
+ (instancetype)infoRowWithTitle:(NSString *)title icon:(nullable NSString *)icon;
@end


@interface SCIActionMenu : NSObject

/// Build a UIMenu from an array of SCIAction. Consecutive actions between
/// `separator` markers are grouped into inline submenus so they render as
/// divided sections (standard iOS menu aesthetic).
+ (UIMenu *)buildMenuWithActions:(NSArray<SCIAction *> *)actions;

/// Build a UIMenu with a header title shown at the top of the menu.
+ (UIMenu *)buildMenuWithActions:(NSArray<SCIAction *> *)actions title:(nullable NSString *)title;

/// Translate a config + action-id resolver into the flat SCIAction array
/// expected by buildMenuWithActions:. Non-collapsible sections render as
/// inline groups separated by SCIAction separators; collapsible sections
/// render as a single submenu SCIAction. Disabled actions and resolver-nil
/// returns are skipped silently. `dateHeader` (when non-nil) becomes the
/// first inline header.
+ (NSArray<SCIAction *> *)actionsForConfig:(SCIActionMenuConfig *)config
                                 dateHeader:(nullable NSString *)dateHeader
                                   resolver:(SCIAction * _Nullable (^)(NSString *actionID))resolver;

@end

NS_ASSUME_NONNULL_END
