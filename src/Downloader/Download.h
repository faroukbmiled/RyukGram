#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../modules/JGProgressHUD/JGProgressHUD.h"

#import "../InstagramHeaders.h"
#import "../Utils.h"

#import "Manager.h"

@interface SCIDownloadPillView : UIView
@property (nonatomic, strong) UIProgressView *progressRing;
@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy) void (^onCancel)(void);

- (void)showInView:(UIView *)view;
- (void)dismiss;
- (void)dismissAfterDelay:(NSTimeInterval)delay;
- (void)setProgress:(float)progress;
- (void)setText:(NSString *)text;
@end

@interface SCIDownloadDelegate : NSObject <SCIDownloadDelegateProtocol>

typedef NS_ENUM(NSUInteger, DownloadAction) {
    share,
    quickLook,
    saveToPhotos
};
@property (nonatomic, readonly) DownloadAction action;
@property (nonatomic, readonly) BOOL showProgress;

@property (nonatomic, strong) SCIDownloadManager *downloadManager;
@property (nonatomic, strong) SCIDownloadPillView *pill;

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress;

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel;

@end
