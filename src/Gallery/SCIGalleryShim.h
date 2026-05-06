// SCIGalleryShim — stub-out upstream-scinsta-1's feedback pill / action
// identifier API so the ported gallery code compiles without pulling in the
// full pill subsystem. Falls back to our existing showToastForDuration: API.

#import <UIKit/UIKit.h>
#import "../Utils.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIFeedbackPillTone) {
    SCIFeedbackPillToneSuccess = 0,
    SCIFeedbackPillToneInfo,
    SCIFeedbackPillToneWarning,
    SCIFeedbackPillToneError
};

extern NSString *const kSCIFeedbackActionGalleryDeleteFile;
extern NSString *const kSCIFeedbackActionGalleryDeleteSelected;
extern NSString *const kSCIFeedbackActionGalleryBulkDelete;
extern NSString *const kSCIFeedbackActionGalleryOpenOriginal;
extern NSString *const kSCIFeedbackActionGalleryOpenProfile;

@interface SCIUtils (SCIGalleryShim)
+ (void)showToastForActionIdentifier:(nullable NSString *)actionIdentifier
                            duration:(NSTimeInterval)duration
                               title:(nullable NSString *)title
                            subtitle:(nullable NSString *)subtitle
                        iconResource:(nullable NSString *)iconResource;
+ (void)showToastForActionIdentifier:(nullable NSString *)actionIdentifier
                            duration:(NSTimeInterval)duration
                               title:(nullable NSString *)title
                            subtitle:(nullable NSString *)subtitle
                        iconResource:(nullable NSString *)iconResource
                                tone:(SCIFeedbackPillTone)tone;
@end

NS_ASSUME_NONNULL_END
