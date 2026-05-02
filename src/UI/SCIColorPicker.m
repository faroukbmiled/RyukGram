#import "SCIColorPicker.h"
#import "../Features/Theme/SCITheme.h"
#import <objc/runtime.h>

static const void *kSCIColorPickerKeyAssoc   = &kSCIColorPickerKeyAssoc;
static const void *kSCIColorPickerOnChange   = &kSCIColorPickerOnChange;

@interface SCIColorPickerProxy : NSObject <UIColorPickerViewControllerDelegate>
+ (instancetype)shared;
@end

@implementation SCIColorPickerProxy

+ (instancetype)shared {
    static SCIColorPickerProxy *p;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ p = [SCIColorPickerProxy new]; });
    return p;
}

- (void)colorPickerViewController:(UIColorPickerViewController *)vc
                   didSelectColor:(UIColor *)color
                     continuously:(BOOL)continuously
{
    NSString *key = objc_getAssociatedObject(vc, kSCIColorPickerKeyAssoc);
    if (key.length) {
        [[NSUserDefaults standardUserDefaults] setObject:[SCITheme hexFromColor:color] forKey:key];
    }
    void (^cb)(UIColor *) = objc_getAssociatedObject(vc, kSCIColorPickerOnChange);
    if (cb) cb(color);
}

@end

@implementation SCIColorPicker

+ (void)presentFrom:(UIViewController *)presenter
              title:(NSString *)title
        defaultsKey:(NSString *)defaultsKey
       defaultColor:(UIColor *)defaultColor
           onChange:(void (^)(UIColor *))onChange
{
    if (!presenter) return;

    UIColorPickerViewController *vc = [[UIColorPickerViewController alloc] init];
    vc.title = title ?: @"";
    vc.supportsAlpha = NO;
    vc.delegate = [SCIColorPickerProxy shared];

    UIColor *current = [SCITheme colorFromHex:[[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey]];
    vc.selectedColor = current ?: (defaultColor ?: [UIColor blackColor]);

    objc_setAssociatedObject(vc, kSCIColorPickerKeyAssoc, defaultsKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (onChange) {
        objc_setAssociatedObject(vc, kSCIColorPickerOnChange, [onChange copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // Single ~88% detent so the user doesn't fight the grabber to expand.
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = vc.sheetPresentationController;
    if (sheet) {
        UISheetPresentationControllerDetent *fit =
            [UISheetPresentationControllerDetent customDetentWithIdentifier:@"sci_picker_fit"
                                                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                return context.maximumDetentValue * 0.88;
            }];
        sheet.detents = @[ fit ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 22;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }

    [presenter presentViewController:vc animated:YES completion:nil];
}

+ (UIView *)swatchViewForKey:(NSString *)defaultsKey defaultColor:(UIColor *)defaultColor {
    UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
    swatch.layer.cornerRadius = 14;
    swatch.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    swatch.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.4].CGColor;

    UIColor *current = [SCITheme colorFromHex:[[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey]];
    swatch.backgroundColor = current ?: (defaultColor ?: [UIColor blackColor]);
    return swatch;
}

@end
