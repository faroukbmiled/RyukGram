#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// RyukGram debug console — permanent reusable module. DO NOT DELETE.
// Disable for release by renaming .m → .m_ (Theos only discovers .m/.x/.xm).
// See CLAUDE.md for usage.

#ifdef __cplusplus
extern "C" {
#endif

void SCIDebugLog(NSString * _Nullable category, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);
NSString *SCIDebugLogDump(void);
void SCIDebugLogClear(void);

#ifdef __cplusplus
}
#endif

@interface SCIDebugLogViewController : UIViewController
+ (void)presentFromTopViewController;
@end

@interface SCIDebugConsole : NSObject
+ (instancetype)shared;
- (void)installIfNeeded;
- (void)show;
- (void)toggleMinimised;
@end
