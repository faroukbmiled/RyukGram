#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryPaths : NSObject

+ (NSString *)galleryDirectory;
+ (NSString *)galleryMediaDirectory;
+ (NSString *)galleryThumbnailsDirectory;

@end

NS_ASSUME_NONNULL_END
