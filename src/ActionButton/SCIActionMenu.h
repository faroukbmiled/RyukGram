#import <UIKit/UIKit.h>

@class SCIActionMenuConfig;
@class SCIActionConfigSection;

NS_ASSUME_NONNULL_BEGIN

@interface SCIAction : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *subtitle;
@property (nonatomic, copy, readonly, nullable) NSString *systemIconName;
@property (nonatomic, copy, readonly, nullable) void (^handler)(void);
@property (nonatomic, copy, readonly, nullable) NSArray<SCIAction *> *children;
@property (nonatomic, assign, readonly) BOOL destructive;
@property (nonatomic, assign, readonly) BOOL isSeparator;
@property (nonatomic, assign, readonly) BOOL disabled;
// Stable id (matches SCIActionCatalog) so handlers survive title localization.
@property (nonatomic, copy, nullable) NSString *actionID;

+ (instancetype)actionWithTitle:(NSString *)title
                           icon:(nullable NSString *)icon
                        handler:(void(^)(void))handler;

// Must be first in the array. Renders as a small grey caption.
+ (instancetype)headerWithTitle:(NSString *)title;

+ (instancetype)actionWithTitle:(NSString *)title
                       subtitle:(nullable NSString *)subtitle
                           icon:(nullable NSString *)icon
                    destructive:(BOOL)destructive
                        handler:(void(^)(void))handler;

+ (instancetype)actionWithTitle:(NSString *)title
                           icon:(nullable NSString *)icon
                       children:(NSArray<SCIAction *> *)children;

// Group divider. Adjacent non-separator actions fold into one inline submenu.
+ (instancetype)separator;

// Greyed-out, non-tappable. For showing context values inside a menu.
+ (instancetype)infoRowWithTitle:(NSString *)title icon:(nullable NSString *)icon;
@end


@interface SCIActionMenu : NSObject

+ (UIMenu *)buildMenuWithActions:(NSArray<SCIAction *> *)actions;
+ (UIMenu *)buildMenuWithActions:(NSArray<SCIAction *> *)actions title:(nullable NSString *)title;

// Walks config sections, asks `resolver` for each action ID, returns the flat
// list ready for buildMenuWithActions:. Disabled actions and nil resolver
// returns are dropped silently. `dateHeader` (if set) becomes the leading
// grey caption.
+ (NSArray<SCIAction *> *)actionsForConfig:(SCIActionMenuConfig *)config
                                 dateHeader:(nullable NSString *)dateHeader
                                   resolver:(SCIAction * _Nullable (^)(NSString *actionID))resolver;

// Same, but `includeDisabled:YES` keeps menu-disabled actions in the list so
// the default-tap path can still fire one the user hid from the menu.
+ (NSArray<SCIAction *> *)actionsForConfig:(SCIActionMenuConfig *)config
                                 dateHeader:(nullable NSString *)dateHeader
                                   resolver:(SCIAction * _Nullable (^)(NSString *actionID))resolver
                            includeDisabled:(BOOL)includeDisabled;

@end

NS_ASSUME_NONNULL_END
