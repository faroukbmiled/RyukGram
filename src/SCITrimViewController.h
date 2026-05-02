// Audio/video trim VC. Caller drives the result through blocks.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SCITrimViewController : UIViewController

@property (nonatomic, strong) NSURL *mediaURL;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, copy)   NSString *sendButtonTitle;
@property (nonatomic, assign) double maxDurationSecs;

@property (nonatomic, copy) void (^onSend)(CMTimeRange trimRange);
@property (nonatomic, copy) void (^onCancel)(void);

@end
