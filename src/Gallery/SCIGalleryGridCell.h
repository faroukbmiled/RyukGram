#import <UIKit/UIKit.h>

@class SCIGalleryFile;

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryGridCell : UICollectionViewCell

- (void)configureWithGalleryFile:(SCIGalleryFile *)file
                 selectionMode:(BOOL)selectionMode
                      selected:(BOOL)selected;

- (void)setSelectionMode:(BOOL)selectionMode selected:(BOOL)selected animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
