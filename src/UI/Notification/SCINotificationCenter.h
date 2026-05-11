#import <UIKit/UIKit.h>
#import "SCINotificationPillView.h"
#import "SCINotificationActions.h"

NS_ASSUME_NONNULL_BEGIN

@class SCINotificationHandle;

@interface SCINotificationCenter : NSObject

+ (instancetype)shared;

- (void)notifyAction:(NSString *)actionID
               title:(NSString *)title
            subtitle:(nullable NSString *)subtitle
                icon:(nullable NSString *)iconSymbol
                tone:(SCINotificationTone)tone;

- (void)notifyAction:(NSString *)actionID
               title:(NSString *)title
            subtitle:(nullable NSString *)subtitle
                icon:(nullable NSString *)iconSymbol
                tone:(SCINotificationTone)tone
            duration:(NSTimeInterval)duration;

- (void)notifyError:(NSString *)actionID
              title:(NSString *)title
            message:(nullable NSString *)message;

// Returns nil when the action's surface is "off". IG-native is forced to pill
// for progress because the IG toast presenter has no progress affordance.
- (nullable SCINotificationHandle *)beginProgressForAction:(NSString *)actionID
                                                     title:(NSString *)title
                                                  onCancel:(nullable void (^)(void))onCancel;

// Indeterminate loading pill. Caller flips to determinate via [handle setProgress:].
- (nullable SCINotificationHandle *)beginLoadingForAction:(NSString *)actionID
                                                    title:(NSString *)title
                                                 onCancel:(nullable void (^)(void))onCancel;

- (void)dismissAll;

// Per-action pref defaults (notif_action_<id> = "default") — merged into
// SCIRegisterDefaultsOnce so picker rows resolve to "Default" on first launch.
+ (NSDictionary<NSString *, NSString *> *)defaultPerActionPrefs;

// Settings preview hooks.
- (void)presentPreviewWithTone:(SCINotificationTone)tone;
- (void)presentPreviewDownloadEndingWithError:(BOOL)endWithError;
- (void)presentPreviewLoadingEndingWithError:(BOOL)endWithError;

@end


@interface SCINotificationHandle : NSObject

@property (nonatomic, readonly, copy) NSString *actionID;
@property (nonatomic, assign, readonly) BOOL isFinished;

- (void)setProgress:(float)progress;
- (void)setIndeterminate:(BOOL)indeterminate;
- (void)setTitle:(NSString *)title;
- (void)setSubtitle:(nullable NSString *)subtitle;

// Terminal transitions — pill lingers ~1.2s then auto-dismisses.
- (void)success:(nullable NSString *)title;
- (void)success:(nullable NSString *)title subtitle:(nullable NSString *)subtitle;
- (void)error:(nullable NSString *)title;
- (void)error:(nullable NSString *)title subtitle:(nullable NSString *)subtitle;
- (void)cancelled:(nullable NSString *)title;

- (void)dismiss;

@end


// C-style convenience callable from any TU (auto-imported via SCIPrefix.h).
FOUNDATION_EXPORT void SCINotify(NSString *actionID, NSString *title, NSString * _Nullable subtitle, NSString * _Nullable iconSymbol, SCINotificationTone tone);
FOUNDATION_EXPORT void SCINotifySuccess(NSString *actionID, NSString *title, NSString * _Nullable subtitle);
FOUNDATION_EXPORT void SCINotifyInfo(NSString *actionID, NSString *title, NSString * _Nullable subtitle);
FOUNDATION_EXPORT void SCINotifyError(NSString *actionID, NSString *title, NSString * _Nullable message);
FOUNDATION_EXPORT void SCINotifyWarning(NSString *actionID, NSString *title, NSString * _Nullable message);
FOUNDATION_EXPORT SCINotificationHandle * _Nullable SCINotifyProgress(NSString *actionID, NSString *title, void (^ _Nullable onCancel)(void));
FOUNDATION_EXPORT SCINotificationHandle * _Nullable SCINotifyLoading(NSString *actionID, NSString *title, void (^ _Nullable onCancel)(void));

NS_ASSUME_NONNULL_END
