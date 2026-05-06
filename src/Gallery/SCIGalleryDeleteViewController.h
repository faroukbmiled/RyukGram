#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIGalleryDeletePageMode) {
    SCIGalleryDeletePageModeRoot = 0,
    SCIGalleryDeletePageModeUsers
};

@interface SCIGalleryDeleteViewController : UITableViewController

@property (nonatomic, copy, nullable) void (^onDidDelete)(void);

- (instancetype)initWithMode:(SCIGalleryDeletePageMode)mode;

@end

NS_ASSUME_NONNULL_END
