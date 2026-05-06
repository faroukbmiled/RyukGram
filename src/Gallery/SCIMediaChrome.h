#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT CGFloat const SCIMediaChromeTopBarContentHeight;
FOUNDATION_EXPORT CGFloat const SCIMediaChromeBottomBarHeight;

UIBlurEffect *SCIMediaChromeBlurEffect(void);
void SCIApplyMediaChromeNavigationBar(UINavigationBar *bar);

UILabel *SCIMediaChromeTitleLabel(NSString *text);
UIImage *SCIMediaChromeTopIcon(NSString *resourceName);
UIImage *SCIMediaChromeBottomIcon(NSString *resourceName);
UIBarButtonItem *SCIMediaChromeTopBarButtonItem(NSString *resourceName, id target, SEL action);

UIView *SCIMediaChromeInstallBottomBar(UIView *hostView);
UIButton *SCIMediaChromeBottomButton(NSString *resourceName, NSString *accessibilityLabel);
UIStackView *SCIMediaChromeInstallBottomRow(UIView *bottomBar, NSArray<UIView *> *row);

NS_ASSUME_NONNULL_END
