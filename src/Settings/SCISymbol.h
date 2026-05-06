#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Settings-cell icon descriptor (name + color + size + weight, optional FB
// asset). For non-settings icon lookups, use SCIIcon directly.
@interface SCISymbol : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly, nullable) NSString *igName;
@property (nonatomic, copy, readonly) UIColor *color;
@property (nonatomic, readonly) CGFloat size;
@property (nonatomic, readonly) UIImageSymbolWeight weight;

- (UIImage *)image;

+ (instancetype)symbolWithName:(NSString *)name;
+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color;
+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color size:(CGFloat)size;
+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color size:(CGFloat)size weight:(UIImageSymbolWeight)weight;

// Explicit FB asset with SF fallback (use when the SF name has no friendly map entry).
+ (instancetype)symbolWithIGName:(NSString *)igName fallback:(NSString *)name;
+ (instancetype)symbolWithIGName:(NSString *)igName fallback:(NSString *)name color:(UIColor *)color;
+ (instancetype)symbolWithIGName:(NSString *)igName fallback:(NSString *)name color:(UIColor *)color size:(CGFloat)size;

@end

NS_ASSUME_NONNULL_END
