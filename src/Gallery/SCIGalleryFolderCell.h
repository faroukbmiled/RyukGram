#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryFolderCell : UICollectionViewCell

/// Folders are list-only; this matches the gallery list row rhythm.
- (void)configureWithFolderName:(NSString *)name itemCount:(NSInteger)itemCount;

@end

NS_ASSUME_NONNULL_END
