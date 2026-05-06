// SCIMediaViewer — full-screen media viewer. Supports single items and carousels.

#import <UIKit/UIKit.h>

/// One media item to display. Set exactly one URL property — viewer dispatches
/// to a video / photo / audio / animated-image page based on which is set.
@interface SCIMediaViewerItem : NSObject
@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) NSURL *photoURL;
@property (nonatomic, strong) NSURL *audioURL;
@property (nonatomic, strong) NSURL *animatedImageURL;
@property (nonatomic, copy)   NSString *caption;
+ (instancetype)itemWithVideoURL:(NSURL *)videoURL photoURL:(NSURL *)photoURL caption:(NSString *)caption;
+ (instancetype)itemWithAudioURL:(NSURL *)audioURL caption:(NSString *)caption;
+ (instancetype)itemWithAnimatedImageURL:(NSURL *)animatedURL caption:(NSString *)caption;
@end

@interface SCIMediaViewer : NSObject

/// Show a single media item.
+ (void)showItem:(SCIMediaViewerItem *)item;

/// Show multiple items (carousel). Starts at the given index.
+ (void)showItems:(NSArray<SCIMediaViewerItem *> *)items startIndex:(NSUInteger)index;

/// Convenience: auto-detect video vs photo for a single item.
+ (void)showWithVideoURL:(NSURL *)videoURL photoURL:(NSURL *)photoURL caption:(NSString *)caption;

@end
