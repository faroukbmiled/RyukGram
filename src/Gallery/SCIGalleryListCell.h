#import <UIKit/UIKit.h>

@class SCIGalleryFile;

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryListCell : UITableViewCell

@property (nonatomic, strong, readonly) SCIGalleryFile *file;

- (void)configureWithGalleryFile:(SCIGalleryFile *)file;

@end

NS_ASSUME_NONNULL_END
