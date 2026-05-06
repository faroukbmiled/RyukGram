#import "SCIMediaViewer.h"
#import "../Utils.h"
#import "../PhotoAlbum.h"
#import "../SCIImageCache.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

// ═══════════════════════════════════════════════════════════════════════════
#pragma mark - Data model
// ═══════════════════════════════════════════════════════════════════════════

@implementation SCIMediaViewerItem
+ (instancetype)itemWithVideoURL:(NSURL *)videoURL photoURL:(NSURL *)photoURL caption:(NSString *)caption {
    SCIMediaViewerItem *i = [SCIMediaViewerItem new];
    i.videoURL = videoURL;
    i.photoURL = photoURL;
    i.caption = caption;
    return i;
}
+ (instancetype)itemWithAudioURL:(NSURL *)audioURL caption:(NSString *)caption {
    SCIMediaViewerItem *i = [SCIMediaViewerItem new];
    i.audioURL = audioURL;
    i.caption = caption;
    return i;
}
+ (instancetype)itemWithAnimatedImageURL:(NSURL *)animatedURL caption:(NSString *)caption {
    SCIMediaViewerItem *i = [SCIMediaViewerItem new];
    i.animatedImageURL = animatedURL;
    i.caption = caption;
    return i;
}
@end


// ═══════════════════════════════════════════════════════════════════════════
#pragma mark - Single photo page
// ═══════════════════════════════════════════════════════════════════════════

@interface _SCIPhotoPageVC : UIViewController <UIScrollViewDelegate>
@property (nonatomic, strong) NSURL *photoURL;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation _SCIPhotoPageVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.delegate = self;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 5.0;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    self.imageView = [[UIImageView alloc] initWithFrame:self.scrollView.bounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scrollView addSubview:self.imageView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.center = self.view.center;
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
                                  | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    [SCIImageCache loadImageFromURL:self.photoURL completion:^(UIImage *img) {
        [self.spinner stopAnimating];
        if (img) self.imageView.image = img;
    }];

    // Double-tap to zoom
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:doubleTap];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv { return self.imageView; }

- (void)handleDoubleTap:(UITapGestureRecognizer *)gr {
    if (self.scrollView.zoomScale > 1.0) {
        [self.scrollView setZoomScale:1.0 animated:YES];
    } else {
        CGPoint pt = [gr locationInView:self.imageView];
        CGRect rect = CGRectMake(pt.x - 50, pt.y - 50, 100, 100);
        [self.scrollView zoomToRect:rect animated:YES];
    }
}

- (UIImage *)currentImage { return self.imageView.image; }

@end


// ═══════════════════════════════════════════════════════════════════════════
#pragma mark - Single video page
// ═══════════════════════════════════════════════════════════════════════════

// Apple's AVPlayerViewController owns the entire video chrome here. The
// container hides its own top + bottom bars while a video page is on screen
// (see updateChrome) so the two UIs never fight.

@interface _SCIVideoPageVC : UIViewController
@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) AVPlayerViewController *playerVC;
@property (nonatomic, strong) AVQueuePlayer *queuePlayer;
@property (nonatomic, strong) AVPlayerLooper *looper;
@end

@implementation _SCIVideoPageVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    // Audio plays even when the silent switch is on.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                            mode:AVAudioSessionModeMoviePlayback
                                         options:0
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.videoURL];
    self.queuePlayer = [AVQueuePlayer queuePlayerWithItems:@[item]];
    self.queuePlayer.muted = [SCIUtils getBoolPref:@"media_zoom_start_muted"];
    self.looper = [AVPlayerLooper playerLooperWithPlayer:self.queuePlayer templateItem:item];

    self.playerVC = [AVPlayerViewController new];
    self.playerVC.player = self.queuePlayer;
    self.playerVC.showsPlaybackControls = YES;
    self.playerVC.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerVC.allowsPictureInPicturePlayback = YES;

    [self addChildViewController:self.playerVC];
    self.playerVC.view.frame = self.view.bounds;
    self.playerVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.playerVC.view];
    [self.playerVC didMoveToParentViewController:self];

    [self.queuePlayer play];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.queuePlayer pause];
    self.queuePlayer = nil;
    self.looper = nil;
    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:nil];
}

@end


// ═══════════════════════════════════════════════════════════════════════════
#pragma mark - Audio page
// ═══════════════════════════════════════════════════════════════════════════

@interface _SCIAudioPageVC : UIViewController
@property (nonatomic, strong) NSURL *audioURL;
@property (nonatomic, strong) AVPlayerViewController *playerVC;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) UIImageView *glyphView;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation _SCIAudioPageVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                            mode:AVAudioSessionModeDefault
                                         options:0
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    self.player = [AVPlayer playerWithURL:self.audioURL];

    self.playerVC = [AVPlayerViewController new];
    self.playerVC.player = self.player;
    self.playerVC.showsPlaybackControls = YES;
    self.playerVC.allowsPictureInPicturePlayback = NO;
    self.playerVC.view.backgroundColor = [UIColor clearColor];
    [self addChildViewController:self.playerVC];

    self.glyphView = [UIImageView new];
    self.glyphView.translatesAutoresizingMaskIntoConstraints = NO;
    self.glyphView.contentMode = UIViewContentModeScaleAspectFit;
    self.glyphView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:200 weight:UIImageSymbolWeightBold];
    self.glyphView.image = [UIImage systemImageNamed:@"waveform" withConfiguration:cfg];
    [self.view addSubview:self.glyphView];

    self.titleLabel = [UILabel new];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.text = self.audioURL.lastPathComponent;
    [self.view addSubview:self.titleLabel];

    self.playerVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.playerVC.view];
    [self.playerVC didMoveToParentViewController:self];

    [NSLayoutConstraint activateConstraints:@[
        [self.glyphView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.glyphView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-60],
        [self.glyphView.widthAnchor constraintEqualToConstant:220],
        [self.glyphView.heightAnchor constraintEqualToConstant:220],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.glyphView.bottomAnchor constant:12],

        [self.playerVC.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.playerVC.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.playerVC.view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-32],
        [self.playerVC.view.heightAnchor constraintEqualToConstant:120],
    ]];

    [self.player play];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.player pause];
    self.player = nil;
}

@end


// ═══════════════════════════════════════════════════════════════════════════
#pragma mark - Animated image page (GIF / animated WebP)
// ═══════════════════════════════════════════════════════════════════════════

@interface _SCIAnimatedPageVC : UIViewController
@property (nonatomic, strong) NSURL *animatedURL;
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation _SCIAnimatedPageVC

// ImageIO frame extraction with per-frame delay → UIImageView.animationImages.
+ (void)loadAnimatedURL:(NSURL *)url completion:(void (^)(NSArray<UIImage *> *frames, NSTimeInterval duration))completion {
    if (!url) { completion(nil, 0); return; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
        if (!src) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, 0); }); return; }
        size_t count = CGImageSourceGetCount(src);
        if (count == 0) { CFRelease(src); dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, 0); }); return; }

        NSMutableArray<UIImage *> *frames = [NSMutableArray arrayWithCapacity:count];
        NSTimeInterval total = 0;
        for (size_t i = 0; i < count; i++) {
            CGImageRef cg = CGImageSourceCreateImageAtIndex(src, i, NULL);
            if (!cg) continue;
            UIImage *img = [UIImage imageWithCGImage:cg];
            CGImageRelease(cg);
            if (img) [frames addObject:img];

            NSTimeInterval delay = 0.1;
            CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(src, i, NULL);
            if (props) {
                CFDictionaryRef gif = CFDictionaryGetValue(props, kCGImagePropertyGIFDictionary);
                if (gif) {
                    NSNumber *un = CFDictionaryGetValue(gif, kCGImagePropertyGIFUnclampedDelayTime);
                    if (![un respondsToSelector:@selector(doubleValue)] || un.doubleValue <= 0) {
                        un = CFDictionaryGetValue(gif, kCGImagePropertyGIFDelayTime);
                    }
                    if ([un respondsToSelector:@selector(doubleValue)] && un.doubleValue > 0) delay = un.doubleValue;
                }
                CFRelease(props);
            }
            total += delay;
        }
        CFRelease(src);
        if (total < 0.04) total = MAX(0.04, frames.count * 0.05);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(frames, total); });
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.imageView = [UIImageView new];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.imageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.imageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    __weak typeof(self) weakSelf = self;
    [_SCIAnimatedPageVC loadAnimatedURL:self.animatedURL completion:^(NSArray<UIImage *> *frames, NSTimeInterval duration) {
        if (!weakSelf || !frames.count) return;
        weakSelf.imageView.animationImages = frames;
        weakSelf.imageView.animationDuration = duration;
        weakSelf.imageView.animationRepeatCount = 0;
        weakSelf.imageView.image = frames.firstObject;
        [weakSelf.imageView startAnimating];
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.imageView stopAnimating];
}

@end


// ═══════════════════════════════════════════════════════════════════════════
#pragma mark - Container VC (PageViewController-based)
// ═══════════════════════════════════════════════════════════════════════════

@interface _SCIMediaViewerContainerVC : UIViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSArray<SCIMediaViewerItem *> *items;
@property (nonatomic, assign) NSUInteger currentIndex;
@property (nonatomic, strong) UIPageViewController *pageVC;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UIButton *shareBtn;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UIView *topShade;
@property (nonatomic, strong) CAGradientLayer *topShadeLayer;
@property (nonatomic, assign) BOOL chromeVisible;
@property (nonatomic, assign) BOOL captionExpanded;
@end

@implementation _SCIMediaViewerContainerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.chromeVisible = YES;

    // Page view controller
    self.pageVC = [[UIPageViewController alloc]
        initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
        navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
        options:nil];
    self.pageVC.dataSource = self.items.count > 1 ? self : nil;
    self.pageVC.delegate = self;

    UIViewController *firstPage = [self viewControllerForIndex:self.currentIndex];
    if (firstPage) [self.pageVC setViewControllers:@[firstPage] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];

    [self addChildViewController:self.pageVC];
    self.pageVC.view.frame = self.view.bounds;
    self.pageVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.pageVC.view];
    [self.pageVC didMoveToParentViewController:self];

    // Top bar — subtle dark gradient so white icons stay readable over light photos.
    self.topBar = [[UIView alloc] init];
    self.topBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.topBar.userInteractionEnabled = YES;
    [self.view addSubview:self.topBar];

    self.topShade = [UIView new];
    self.topShade.translatesAutoresizingMaskIntoConstraints = NO;
    self.topShade.userInteractionEnabled = NO;
    [self.view insertSubview:self.topShade belowSubview:self.topBar];
    self.topShadeLayer = [CAGradientLayer layer];
    self.topShadeLayer.colors = @[
        (id)[[[UIColor blackColor] colorWithAlphaComponent:0.55] CGColor],
        (id)[[UIColor clearColor] CGColor],
    ];
    self.topShadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.topShadeLayer.endPoint = CGPointMake(0.5, 1.0);
    [self.topShade.layer addSublayer:self.topShadeLayer];

    [NSLayoutConstraint activateConstraints:@[
        [self.topShade.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topShade.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topShade.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topShade.heightAnchor constraintEqualToConstant:120.0],
    ]];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];

    self.closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:cfg] forState:UIControlStateNormal];
    self.closeBtn.tintColor = [UIColor whiteColor];
    self.closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeBtn];

    self.shareBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.shareBtn setImage:[UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:cfg] forState:UIControlStateNormal];
    self.shareBtn.tintColor = [UIColor whiteColor];
    self.shareBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.shareBtn addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.shareBtn];

    self.counterLabel = [[UILabel alloc] init];
    self.counterLabel.textColor = [UIColor whiteColor];
    self.counterLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.counterLabel.textAlignment = NSTextAlignmentCenter;
    self.counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topBar addSubview:self.counterLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.topBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.topBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topBar.heightAnchor constraintEqualToConstant:44],
        [self.closeBtn.leadingAnchor constraintEqualToAnchor:self.topBar.leadingAnchor constant:16],
        [self.closeBtn.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
        [self.shareBtn.trailingAnchor constraintEqualToAnchor:self.topBar.trailingAnchor constant:-16],
        [self.shareBtn.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
        [self.counterLabel.centerXAnchor constraintEqualToAnchor:self.topBar.centerXAnchor],
        [self.counterLabel.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
    ]];

    // Bottom bar (caption — tap to expand/collapse)
    self.bottomBar = [[UIView alloc] init];
    self.bottomBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomBar];

    self.captionLabel = [[UILabel alloc] init];
    self.captionLabel.textColor = [UIColor whiteColor];
    self.captionLabel.font = [UIFont systemFontOfSize:14];
    self.captionLabel.numberOfLines = 3; // collapsed
    self.captionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.captionLabel.userInteractionEnabled = YES;
    [self.bottomBar addSubview:self.captionLabel];

    UITapGestureRecognizer *captionTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(toggleCaption)];
    [self.captionLabel addGestureRecognizer:captionTap];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.captionLabel.topAnchor constraintEqualToAnchor:self.bottomBar.topAnchor constant:12],
        [self.captionLabel.leadingAnchor constraintEqualToAnchor:self.bottomBar.leadingAnchor constant:16],
        [self.captionLabel.trailingAnchor constraintEqualToAnchor:self.bottomBar.trailingAnchor constant:-16],
        [self.captionLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
    ]];

    // Swipe down to dismiss
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissPan:)];
    pan.delegate = (id<UIGestureRecognizerDelegate>)self;
    [self.view addGestureRecognizer:pan];

    // Single tap toggles chrome
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleChrome)];
    tap.cancelsTouchesInView = NO;
    [self.pageVC.view addGestureRecognizer:tap];

    [self updateChrome];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.topShadeLayer.frame = self.topShade.bounds;
}

- (void)updateChrome {
    SCIMediaViewerItem *item = self.items[self.currentIndex];
    BOOL isVideo = (item.videoURL != nil);

    // Counter — always visible when there's more than one item, including
    // on video pages so the user always knows where they are.
    if (self.items.count > 1) {
        self.counterLabel.text = [NSString stringWithFormat:@"%lu / %lu",
                                   (unsigned long)(self.currentIndex + 1),
                                   (unsigned long)self.items.count];
        self.counterLabel.hidden = NO;
    } else {
        self.counterLabel.hidden = YES;
    }

    // On video pages, hide our close + share buttons + gradient shade so
    // AVPlayerViewController's chrome doesn't fight us. The counter stays.
    BOOL hideForVideo = isVideo;
    [UIView animateWithDuration:0.18 animations:^{
        self.closeBtn.alpha = hideForVideo ? 0.0 : 1.0;
        self.shareBtn.alpha = hideForVideo ? 0.0 : 1.0;
        self.topShade.alpha = hideForVideo ? 0.0 : 1.0;
    }];
    self.closeBtn.userInteractionEnabled = !hideForVideo;
    self.shareBtn.userInteractionEnabled = !hideForVideo;

    BOOL hideCaption = isVideo;
    if (item.caption.length && !hideCaption) {
        self.captionLabel.text = item.caption;
        self.bottomBar.hidden = NO;
    } else {
        self.bottomBar.hidden = YES;
    }
}

- (void)toggleChrome {
    self.chromeVisible = !self.chromeVisible;
    [UIView animateWithDuration:0.25 animations:^{
        CGFloat a = self.chromeVisible ? 1.0 : 0.0;
        self.topBar.alpha = a;
        self.topShade.alpha = a;
        self.bottomBar.alpha = a;
    }];
}

- (void)toggleCaption {
    self.captionExpanded = !self.captionExpanded;
    [UIView animateWithDuration:0.25 animations:^{
        self.captionLabel.numberOfLines = self.captionExpanded ? 0 : 3;
        [self.view layoutIfNeeded];
    }];
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gr {
    if (![gr isKindOfClass:[UIPanGestureRecognizer class]]) return YES;
    CGPoint v = [gr velocityInView:self.view];
    return fabs(v.y) > fabs(v.x) && v.y > 0;
}

- (void)handleDismissPan:(UIPanGestureRecognizer *)gr {
    CGFloat ty = [gr translationInView:self.view].y;
    CGFloat h = self.view.bounds.size.height;
    CGFloat progress = fmin(fmax(ty / h, 0), 1);

    switch (gr.state) {
        case UIGestureRecognizerStateChanged: {
            self.view.transform = CGAffineTransformMakeTranslation(0, ty);
            self.view.alpha = 1.0 - progress * 0.5;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat vy = [gr velocityInView:self.view].y;
            if (progress > 0.25 || vy > 800) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.view.transform = CGAffineTransformMakeTranslation(0, h);
                    self.view.alpha = 0;
                } completion:^(BOOL finished) {
                    [self dismissViewControllerAnimated:NO completion:nil];
                }];
            } else {
                [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{
                    self.view.transform = CGAffineTransformIdentity;
                    self.view.alpha = 1;
                } completion:nil];
            }
            break;
        }
        default: break;
    }
}

- (void)closeTapped {
    // Pause any playing video before tearing down.
    UIViewController *current = self.pageVC.viewControllers.firstObject;
    if ([current isKindOfClass:[_SCIVideoPageVC class]]) {
        [((_SCIVideoPageVC *)current).queuePlayer pause];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Sniff container format from magic bytes. WebP routes through a PNG transcode
// because Save-to-Photos rejects .webp on most iOS versions.
static NSString *sciSniffImageExt(NSData *data, BOOL *needsTranscode) {
    if (needsTranscode) *needsTranscode = NO;
    if (data.length < 12) return @"jpg";
    const uint8_t *b = data.bytes;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return @"jpg";
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return @"png";
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return @"gif";
    if (b[4] == 'f' && b[5] == 't' && b[6] == 'y' && b[7] == 'p') {
        if ((b[8] == 'h' && (b[9] == 'e' || b[9] == 'v')) || (b[8] == 'm' && (b[9] == 'i' || b[9] == 's')))
            return @"heic";
    }
    if (b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' &&
        b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') {
        if (needsTranscode) *needsTranscode = YES;
        return @"png";
    }
    return @"jpg";
}

- (void)shareTapped {
    SCIMediaViewerItem *item = self.items[self.currentIndex];
    UIViewController *current = self.pageVC.viewControllers.firstObject;
    BOOL isPhoto = [current isKindOfClass:[_SCIPhotoPageVC class]];

    // Audio + animated GIF — local file URL passes straight to the share sheet.
    if (item.audioURL || item.animatedImageURL) {
        NSURL *url = item.audioURL ?: item.animatedImageURL;
        UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        vc.popoverPresentationController.sourceView = self.shareBtn;
        [self presentViewController:vc animated:YES completion:nil];
        return;
    }

    if (!isPhoto) {
        NSURL *url = item.videoURL ?: item.photoURL;
        if (!url) return;
        UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        vc.popoverPresentationController.sourceView = self.shareBtn;
        [SCIPhotoAlbum armWatcherIfEnabled];
        [self presentViewController:vc animated:YES completion:nil];
        return;
    }

    // Share original bytes in a temp file with the correct extension — sharing a
    // raw UIImage breaks Save-to-Photos for WebP-sourced images (e.g. profile pics).
    if (!item.photoURL) return;
    UIImage *fallbackImg = [(_SCIPhotoPageVC *)current currentImage];
    __weak typeof(self) weakSelf = self;

    [SCIImageCache loadDataFromURL:item.photoURL completion:^(NSData *data) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSMutableArray *shareItems = [NSMutableArray array];
        NSURL *tempFileURL = nil;

        if (data.length) {
            BOOL transcode = NO;
            NSString *ext = sciSniffImageExt(data, &transcode);
            NSData *out = data;
            if (transcode) {
                UIImage *decoded = [UIImage imageWithData:data];
                NSData *png = decoded ? UIImagePNGRepresentation(decoded) : nil;
                if (png) out = png; else ext = @"webp";
            }
            NSString *name = [NSString stringWithFormat:@"sci_share_%@.%@", [[NSUUID UUID] UUIDString], ext];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
            if ([out writeToFile:path atomically:YES]) {
                tempFileURL = [NSURL fileURLWithPath:path];
                [shareItems addObject:tempFileURL];
            }
        }

        if (!shareItems.count && fallbackImg) [shareItems addObject:fallbackImg];
        if (!shareItems.count) [shareItems addObject:item.photoURL];

        UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:shareItems applicationActivities:nil];
        vc.popoverPresentationController.sourceView = strongSelf.shareBtn;
        NSURL *toClean = tempFileURL;
        vc.completionWithItemsHandler = ^(UIActivityType _Nullable type, BOOL completed, NSArray *items, NSError *err) {
            if (toClean) [[NSFileManager defaultManager] removeItemAtURL:toClean error:nil];
        };
        [SCIPhotoAlbum armWatcherIfEnabled];
        [strongSelf presentViewController:vc animated:YES completion:nil];
    }];
}

// ─── Page data source ───

- (UIViewController *)viewControllerForIndex:(NSUInteger)idx {
    if (idx >= self.items.count) return nil;
    SCIMediaViewerItem *item = self.items[idx];

    if (item.videoURL) {
        _SCIVideoPageVC *vc = [[_SCIVideoPageVC alloc] init];
        vc.videoURL = item.videoURL;
        vc.view.tag = (NSInteger)idx;
        return vc;
    } else if (item.audioURL) {
        _SCIAudioPageVC *vc = [[_SCIAudioPageVC alloc] init];
        vc.audioURL = item.audioURL;
        vc.view.tag = (NSInteger)idx;
        return vc;
    } else if (item.animatedImageURL) {
        _SCIAnimatedPageVC *vc = [[_SCIAnimatedPageVC alloc] init];
        vc.animatedURL = item.animatedImageURL;
        vc.view.tag = (NSInteger)idx;
        return vc;
    } else if (item.photoURL) {
        _SCIPhotoPageVC *vc = [[_SCIPhotoPageVC alloc] init];
        vc.photoURL = item.photoURL;
        vc.view.tag = (NSInteger)idx;
        return vc;
    }
    return nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pvc viewControllerBeforeViewController:(UIViewController *)vc {
    NSInteger idx = vc.view.tag;
    if (idx <= 0) return nil;
    return [self viewControllerForIndex:idx - 1];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pvc viewControllerAfterViewController:(UIViewController *)vc {
    NSInteger idx = vc.view.tag;
    if (idx + 1 >= (NSInteger)self.items.count) return nil;
    return [self viewControllerForIndex:idx + 1];
}

- (void)pageViewController:(UIPageViewController *)pvc didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)prev transitionCompleted:(BOOL)completed {
    if (!completed) return;
    UIViewController *current = pvc.viewControllers.firstObject;
    self.currentIndex = (NSUInteger)current.view.tag;

    for (UIViewController *p in prev) {
        if ([p isKindOfClass:[_SCIVideoPageVC class]]) {
            [((_SCIVideoPageVC *)p).queuePlayer pause];
        } else if ([p isKindOfClass:[_SCIAudioPageVC class]]) {
            [((_SCIAudioPageVC *)p).player pause];
        } else if ([p isKindOfClass:[_SCIAnimatedPageVC class]]) {
            [((_SCIAnimatedPageVC *)p).imageView stopAnimating];
        }
    }
    if ([current isKindOfClass:[_SCIVideoPageVC class]]) {
        [((_SCIVideoPageVC *)current).queuePlayer play];
    } else if ([current isKindOfClass:[_SCIAudioPageVC class]]) {
        [((_SCIAudioPageVC *)current).player play];
    } else if ([current isKindOfClass:[_SCIAnimatedPageVC class]]) {
        [((_SCIAnimatedPageVC *)current).imageView startAnimating];
    }

    [self updateChrome];
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }

@end


// ═══════════════════════════════════════════════════════════════════════════
#pragma mark - Public API
// ═══════════════════════════════════════════════════════════════════════════

@implementation SCIMediaViewer

+ (void)presentNativeVideoPlayer:(NSURL *)url {
    dispatch_async(dispatch_get_main_queue(), ^{
        AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
        playerVC.player = [AVPlayer playerWithURL:url];
        playerVC.player.muted = [SCIUtils getBoolPref:@"media_zoom_start_muted"];
        playerVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [topMostController() presentViewController:playerVC animated:YES completion:^{
            [playerVC.player play];
        }];
    });
}

+ (void)showItem:(SCIMediaViewerItem *)item {
    if (!item) { [SCIUtils showErrorHUDWithDescription:SCILocalized(@"No media to show")]; return; }

    // Single video → native AVPlayerViewController directly (no wrapper)
    if (item.videoURL) {
        [self presentNativeVideoPlayer:item.videoURL];
        return;
    }

    // Single photo → use our photo viewer container
    [self showItems:@[item] startIndex:0];
}

+ (void)showItems:(NSArray<SCIMediaViewerItem *> *)items startIndex:(NSUInteger)index {
    if (!items.count) { [SCIUtils showErrorHUDWithDescription:SCILocalized(@"No media to show")]; return; }
    if (index >= items.count) index = 0;

    // Single video item → native player
    if (items.count == 1 && items[0].videoURL) {
        [self presentNativeVideoPlayer:items[0].videoURL];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        _SCIMediaViewerContainerVC *vc = [[_SCIMediaViewerContainerVC alloc] init];
        vc.items = items;
        vc.currentIndex = index;
        vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
        vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [topMostController() presentViewController:vc animated:YES completion:nil];
    });
}

+ (void)showWithVideoURL:(NSURL *)videoURL photoURL:(NSURL *)photoURL caption:(NSString *)caption {
    [self showItem:[SCIMediaViewerItem itemWithVideoURL:videoURL photoURL:photoURL caption:caption]];
}

@end
