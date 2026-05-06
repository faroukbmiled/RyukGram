// SCIAssetUtils — thin compatibility shim for upstream-scinsta-1's asset
// helper API. Routes everything through our existing SCIIcon resolver.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIAssetCatalogSource) {
    SCIAssetCatalogSourceAutomatic = 0,
    SCIAssetCatalogSourceFBSharedFramework = 1,
    SCIAssetCatalogSourceMainApp = 2,
};

typedef NS_ENUM(NSInteger, SCIResolvedImageSource) {
    SCIResolvedImageSourceAutomatic = 0,
    SCIResolvedImageSourceInstagramIcon = 1,
    SCIResolvedImageSourceSystemSymbol = 2,
};

@interface SCIAssetUtils : NSObject

+ (nullable UIImage *)instagramIconNamed:(NSString *)name;
+ (nullable UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize;
+ (nullable UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize renderingMode:(UIImageRenderingMode)renderingMode;
+ (nullable UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize source:(SCIAssetCatalogSource)source;
+ (nullable UIImage *)instagramIconNamed:(NSString *)name
                               pointSize:(CGFloat)pointSize
                                  source:(SCIAssetCatalogSource)source
                           renderingMode:(UIImageRenderingMode)renderingMode;

+ (nullable UIImage *)resolvedImageNamed:(NSString *)name
                               pointSize:(CGFloat)pointSize
                                  weight:(UIImageSymbolWeight)weight
                                  source:(SCIResolvedImageSource)source
                           renderingMode:(UIImageRenderingMode)renderingMode;

+ (nullable UIImage *)resolvedImageNamed:(nullable NSString *)name
                      fallbackSystemName:(nullable NSString *)fallbackSystemName
                               pointSize:(CGFloat)pointSize
                                  weight:(UIImageSymbolWeight)weight
                                  source:(SCIResolvedImageSource)source
                           renderingMode:(UIImageRenderingMode)renderingMode;

@end

NS_ASSUME_NONNULL_END
