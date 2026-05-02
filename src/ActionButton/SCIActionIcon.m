#import "SCIActionIcon.h"
#import "../Utils.h"
#import "../SCIPrefObserver.h"
#import <objc/runtime.h>

NSString *const SCIActionIconPrefKey       = @"action_button_icon";
NSString *const SCIActionIconDefaultName   = @"ellipsis.circle";
NSString *const SCIActionIconDidChangeNote = @"SCIActionIconDidChange";

static const void *kSCIActionIconConfigKey = &kSCIActionIconConfigKey;

@interface SCIActionIconConfig : NSObject
@property (nonatomic, assign) CGFloat pointSize;
@property (nonatomic, assign) SCIActionIconStyle style;
@end
@implementation SCIActionIconConfig
@end


@implementation SCIActionIcon

+ (NSHashTable<SCIChromeButton *> *)attached {
    static NSHashTable *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ t = [NSHashTable weakObjectsHashTable]; });
    return t;
}

+ (void)ensureObserver {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [SCIPrefObserver observeKey:SCIActionIconPrefKey handler:^{
            [self broadcastChange];
        }];
    });
}

+ (void)broadcastChange {
    for (SCIChromeButton *btn in [[self attached] allObjects]) {
        SCIActionIconConfig *cfg = objc_getAssociatedObject(btn, kSCIActionIconConfigKey);
        if (!cfg) continue;
        [self applyToButton:btn pointSize:cfg.pointSize style:cfg.style];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SCIActionIconDidChangeNote object:nil];
}

+ (NSString *)symbolName {
    NSString *raw = [SCIUtils getStringPref:SCIActionIconPrefKey];
    if (!raw.length) return SCIActionIconDefaultName;
    if (![UIImage systemImageNamed:raw]) return SCIActionIconDefaultName;
    return raw;
}

+ (void)setSymbolName:(NSString *)name {
    if (!name.length) return;
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:SCIActionIconPrefKey];
    if ([current isEqualToString:name]) return;
    [[NSUserDefaults standardUserDefaults] setObject:name forKey:SCIActionIconPrefKey];
}

+ (NSArray<NSString *> *)availableSystemIcons {
    // Curated to "more / open menu / take action" reads. Anything mirroring
    // a specific IG affordance (eye, camera, bookmark, bell, lock, chart) is
    // excluded so the icon never miscommunicates intent.
    return @[
        // Dots / "more"
        @"ellipsis.circle", @"ellipsis.circle.fill", @"ellipsis", @"ellipsis.rectangle",
        @"circle.grid.2x2", @"circle.grid.2x2.fill", @"circle.grid.3x3", @"square.grid.2x2",
        @"line.3.horizontal", @"line.3.horizontal.circle", @"line.3.horizontal.circle.fill",
        // Plus / dismiss
        @"plus.circle", @"plus.circle.fill", @"plus.app", @"plus.app.fill",
        @"xmark.circle", @"xmark.circle.fill",
        // Arrows
        @"arrow.down.circle", @"arrow.down.circle.fill",
        @"arrow.up.circle", @"arrow.up.circle.fill",
        @"arrow.up.right.circle", @"arrow.up.right.circle.fill",
        @"square.and.arrow.down", @"square.and.arrow.down.fill",
        @"square.and.arrow.up", @"square.and.arrow.up.fill",
        @"arrow.triangle.2.circlepath", @"arrow.triangle.2.circlepath.circle",
        @"arrow.down", @"arrow.down.to.line", @"arrow.down.to.line.compact",
        @"arrow.down.app", @"arrow.down.app.fill",
        @"arrow.down.square", @"arrow.down.square.fill",
        @"tray.and.arrow.down", @"tray.and.arrow.down.fill",
        @"icloud.and.arrow.down", @"icloud.and.arrow.down.fill",
        // Tools / settings
        @"gear", @"gearshape", @"gearshape.fill", @"gearshape.2", @"gearshape.2.fill",
        @"slider.horizontal.3", @"slider.vertical.3",
        @"wrench", @"wrench.fill", @"wrench.and.screwdriver", @"wrench.and.screwdriver.fill",
        @"hammer", @"hammer.fill", @"hammer.circle", @"hammer.circle.fill",
        @"command", @"command.circle", @"command.circle.fill", @"command.square", @"command.square.fill",
        // Magic / power
        @"sparkle", @"sparkles", @"wand.and.stars", @"wand.and.stars.inverse",
        @"star", @"star.fill", @"star.circle", @"star.circle.fill",
        @"bolt", @"bolt.fill", @"bolt.circle", @"bolt.circle.fill",
        @"flame", @"flame.fill",
        // Flair
        @"heart", @"heart.fill", @"heart.circle", @"heart.circle.fill",
        @"crown", @"crown.fill", @"leaf", @"leaf.fill", @"hare", @"hare.fill",
        @"moon", @"moon.fill", @"sun.max", @"sun.max.fill",
        @"gift", @"gift.fill", @"gift.circle", @"gift.circle.fill",
    ];
}

+ (UIImage *)plainImageForPointSize:(CGFloat)pointSize {
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                         weight:UIImageSymbolWeightSemibold];
    return [UIImage systemImageNamed:[self symbolName] withConfiguration:cfg];
}

+ (UIImage *)shadowBakedImageForPointSize:(CGFloat)pointSize {
    UIImage *base = [self plainImageForPointSize:pointSize];
    if (!base) return nil;

    CGFloat pad = 8;
    CGSize sz = CGSizeMake(base.size.width + pad * 2, base.size.height + pad * 2);
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:sz];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGContextSaveGState(c);
        CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 3,
            [UIColor colorWithWhite:0 alpha:0.55].CGColor);
        UIImage *tinted = [base imageWithTintColor:[UIColor whiteColor]
                                     renderingMode:UIImageRenderingModeAlwaysOriginal];
        [tinted drawInRect:CGRectMake(pad, pad, base.size.width, base.size.height)];
        CGContextRestoreGState(c);
    }];
}

+ (void)applyToButton:(SCIChromeButton *)button
            pointSize:(CGFloat)pointSize
                style:(SCIActionIconStyle)style {
    if (!button) return;
    if (style == SCIActionIconStyleShadowBaked) {
        button.symbolName = @"";
        button.iconView.image = [self shadowBakedImageForPointSize:pointSize];
    } else {
        button.symbolPointSize = pointSize;
        button.symbolName = [self symbolName];
    }
}

+ (void)attachAutoUpdate:(SCIChromeButton *)button
               pointSize:(CGFloat)pointSize
                   style:(SCIActionIconStyle)style {
    if (!button) return;
    [self ensureObserver];

    SCIActionIconConfig *cfg = [SCIActionIconConfig new];
    cfg.pointSize = pointSize;
    cfg.style = style;
    objc_setAssociatedObject(button, kSCIActionIconConfigKey, cfg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self attached] addObject:button];

    [self applyToButton:button pointSize:pointSize style:style];
}

@end
