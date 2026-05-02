// SCIActionIcon — global icon source for every RyukGram action button.

#import <UIKit/UIKit.h>
#import "../SCIChrome.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SCIActionIconPrefKey;
extern NSString *const SCIActionIconDefaultName;
extern NSString *const SCIActionIconDidChangeNote;

typedef NS_ENUM(NSInteger, SCIActionIconStyle) {
    SCIActionIconStylePlain = 0,
    // Reels — floats on media, needs baked drop shadow instead of a bubble.
    SCIActionIconStyleShadowBaked,
};

@interface SCIActionIcon : NSObject

+ (NSString *)symbolName;
+ (NSArray<NSString *> *)availableSystemIcons;
+ (void)setSymbolName:(NSString *)name;

+ (void)applyToButton:(SCIChromeButton *)button
            pointSize:(CGFloat)pointSize
                style:(SCIActionIconStyle)style;

// Apply now and re-apply on every pref change. Button is held weakly.
+ (void)attachAutoUpdate:(SCIChromeButton *)button
               pointSize:(CGFloat)pointSize
                   style:(SCIActionIconStyle)style;

@end

NS_ASSUME_NONNULL_END
