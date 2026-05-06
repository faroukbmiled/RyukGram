#import <Foundation/Foundation.h>

@class SCIGalleryFile;
@class SCIGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryOriginController : NSObject

+ (void)populateMetadata:(SCIGallerySaveMetadata *)metadata fromMedia:(id _Nullable)media;
+ (void)populateProfileMetadata:(SCIGallerySaveMetadata *)metadata username:(nullable NSString *)username user:(id _Nullable)user;
+ (BOOL)openOriginalPostForGalleryFile:(SCIGalleryFile *)file;
+ (BOOL)openProfileForGalleryFile:(SCIGalleryFile *)file;

@end

NS_ASSUME_NONNULL_END
