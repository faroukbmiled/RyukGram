// Reusable color picker — wraps UIColorPickerViewController and persists the
// chosen color as a `#RRGGBB` hex string under a NSUserDefaults key.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIColorPicker : NSObject

+ (void)presentFrom:(UIViewController *)presenter
              title:(NSString *)title
        defaultsKey:(NSString *)defaultsKey
       defaultColor:(nullable UIColor *)defaultColor
           onChange:(void (^ _Nullable)(UIColor *color))onChange;

// Round swatch suitable as a UITableViewCell `accessoryView`.
+ (UIView *)swatchViewForKey:(NSString *)defaultsKey
                defaultColor:(nullable UIColor *)defaultColor;

@end

NS_ASSUME_NONNULL_END
