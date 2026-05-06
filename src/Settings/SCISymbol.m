#import "SCISymbol.h"
#import "../UI/SCIIcon.h"
#import "../Localization/SCILocalization.h"

@interface SCISymbol ()

@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite, nullable) NSString *igName;
@property (nonatomic, copy, readwrite) UIColor *color;
@property (nonatomic, readwrite) CGFloat size;
@property (nonatomic, readwrite) UIImageSymbolWeight weight;

@end

@implementation SCISymbol

- (instancetype)init {
    self = [super init];
    if (self) {
        self.name = @"";
        self.color = [UIColor labelColor];
        self.weight = UIImageSymbolWeightRegular;
        self.size = 15.0;
    }
    return self;
}

- (UIImage *)image {
    // FB asset (explicit igName, else friendly map for self.name) sized
    // slightly larger than text so it reads at parity with SF symbols.
    NSString *fbName = self.igName.length ? self.igName : self.name;
    UIImage *fb = [SCIIcon fbImageNamed:fbName pointSize:(self.size > 0 ? self.size + 6.0 : 0)];
    if (fb) return fb;

    // SF with Dynamic-Type-aware config (settings cells scale with text size).
    UIImage *sym = [SCIIcon sfImageNamed:self.name];
    if (sym && self.size > 0) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleTitle1];
        cfg = [cfg configurationByApplyingConfiguration:
               [UIImageSymbolConfiguration configurationWithPointSize:self.size weight:self.weight]];
        return [sym imageWithConfiguration:cfg];
    }
    if (sym) return sym;

    NSBundle *bundle = SCILocalizationBundle();
    UIImage *bundled = bundle ? [UIImage imageNamed:self.name inBundle:bundle compatibleWithTraitCollection:nil] : nil;
    return [bundled imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

// MARK: - Factories

+ (instancetype)symbolWithName:(NSString *)name {
    SCISymbol *s = [self new];
    s.name = name;
    return s;
}

+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color {
    SCISymbol *s = [self new];
    s.name = name;
    s.color = color;
    return s;
}

+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color size:(CGFloat)size {
    SCISymbol *s = [self new];
    s.name = name;
    s.color = color;
    s.size = size;
    return s;
}

+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color size:(CGFloat)size weight:(UIImageSymbolWeight)weight {
    SCISymbol *s = [self new];
    s.name = name;
    s.color = color;
    s.size = size;
    s.weight = weight;
    return s;
}

+ (instancetype)symbolWithIGName:(NSString *)igName fallback:(NSString *)name {
    SCISymbol *s = [self new];
    s.igName = igName;
    s.name = name ?: @"";
    return s;
}

+ (instancetype)symbolWithIGName:(NSString *)igName fallback:(NSString *)name color:(UIColor *)color {
    SCISymbol *s = [self new];
    s.igName = igName;
    s.name = name ?: @"";
    s.color = color;
    return s;
}

+ (instancetype)symbolWithIGName:(NSString *)igName fallback:(NSString *)name color:(UIColor *)color size:(CGFloat)size {
    SCISymbol *s = [self new];
    s.igName = igName;
    s.name = name ?: @"";
    s.color = color;
    s.size = size;
    return s;
}

@end
