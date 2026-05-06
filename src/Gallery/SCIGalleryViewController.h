#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SCIGalleryFile;

@interface SCIGalleryViewController : UIViewController

+ (void)presentGallery;

/// Initializes the gallery for browsing the given folder path. Pass nil for root.
- (instancetype)initWithFolderPath:(nullable NSString *)folderPath;

/// Picker presentation — single-tap-to-select, pre-filtered to the given
/// media types (NSNumber-wrapped SCIGalleryMediaType). Completion fires with
/// the picked file URL, or nil on cancel.
+ (void)presentPickerWithMediaTypes:(nullable NSArray<NSNumber *> *)allowedMediaTypes
                              title:(nullable NSString *)title
                             fromVC:(UIViewController *)fromVC
                         completion:(void (^)(NSURL * _Nullable pickedURL,
                                              SCIGalleryFile * _Nullable pickedFile))completion;

@end

NS_ASSUME_NONNULL_END
