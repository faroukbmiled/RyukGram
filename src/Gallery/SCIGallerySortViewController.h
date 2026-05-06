#import <UIKit/UIKit.h>
#import "SCIGallerySheetViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIGallerySortMode) {
    SCIGallerySortModeDateAddedDesc = 0,  // Newest first (default)
    SCIGallerySortModeDateAddedAsc,       // Oldest first
    SCIGallerySortModeNameAsc,            // A→Z
    SCIGallerySortModeNameDesc,           // Z→A
    SCIGallerySortModeSizeDesc,           // Largest first
    SCIGallerySortModeSizeAsc,            // Smallest first
    SCIGallerySortModeTypeAsc,            // Images then videos
    SCIGallerySortModeTypeDesc,           // Videos then images
};

@class SCIGallerySortViewController;

@protocol SCIGallerySortViewControllerDelegate <NSObject>
- (void)sortController:(SCIGallerySortViewController *)controller didSelectSortMode:(SCIGallerySortMode)mode;
@end

@interface SCIGallerySortViewController : SCIGallerySheetViewController

@property (nonatomic, weak) id<SCIGallerySortViewControllerDelegate> delegate;
@property (nonatomic, assign) SCIGallerySortMode currentSortMode;

+ (NSArray<NSSortDescriptor *> *)sortDescriptorsForMode:(SCIGallerySortMode)mode;
+ (NSString *)labelForMode:(SCIGallerySortMode)mode;

@end

NS_ASSUME_NONNULL_END
