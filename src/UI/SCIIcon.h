#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Icon resolver — accepts friendly keys ("eye"), SF symbol names ("eye.fill"),
// or raw catalog names ("ig_icon_eye_outline_24"). FB assets render template-
// mode so tintColor controls the color.
@interface SCIIcon : NSObject

// Hybrid: FB if mapped, else SF symbol, else bundle PNG.
+ (nullable UIImage *)imageNamed:(NSString *)name;
+ (nullable UIImage *)imageNamed:(NSString *)name pointSize:(CGFloat)pointSize;
+ (nullable UIImage *)imageNamed:(NSString *)name pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight;
+ (nullable UIImage *)imageNamed:(NSString *)name configuration:(nullable UIImageSymbolConfiguration *)config;

// FB-only — nil if no FB asset registered.
+ (nullable UIImage *)fbImageNamed:(NSString *)name;
+ (nullable UIImage *)fbImageNamed:(NSString *)name pointSize:(CGFloat)pointSize;

// SF-only — nil if no SF symbol with that name.
+ (nullable UIImage *)sfImageNamed:(NSString *)name;
+ (nullable UIImage *)sfImageNamed:(NSString *)name pointSize:(CGFloat)pointSize;
+ (nullable UIImage *)sfImageNamed:(NSString *)name pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight;
+ (nullable UIImage *)sfImageNamed:(NSString *)name configuration:(nullable UIImageSymbolConfiguration *)config;

@end

NS_ASSUME_NONNULL_END
