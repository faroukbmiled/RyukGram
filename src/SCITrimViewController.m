#import "SCITrimViewController.h"
#import "Utils.h"

static const CGFloat kTrackH = 56.0;
static const CGFloat kHandleW = 16.0;
static const CGFloat kHandleHitW = 48.0;
static const CGFloat kTrackMargin = 24.0;

@interface SCITrimViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *rangeLabel;
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) UIView *selectedRange;
@property (nonatomic, strong) UIView *leftHandle;
@property (nonatomic, strong) UIView *rightHandle;
@property (nonatomic, strong) UIView *playhead;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIButton *stopBtn;
@property (nonatomic, assign) double totalDuration;
@property (nonatomic, assign) double startTime;
@property (nonatomic, assign) double endTime;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) id timeObserver;
@end

@implementation SCITrimViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    AVAsset *asset = [AVAsset assetWithURL:self.mediaURL];
    self.totalDuration = CMTimeGetSeconds(asset.duration);
    self.startTime = 0;
    self.endTime = self.totalDuration;
    if (self.maxDurationSecs > 0 && self.endTime - self.startTime > self.maxDurationSecs) {
        self.endTime = self.startTime + self.maxDurationSecs;
    }

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    self.player = [AVPlayer playerWithURL:self.mediaURL];

    __weak SCITrimViewController *weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.03, 600) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        SCITrimViewController *s = weakSelf;
        if (!s || !s.isPlaying) return;
        if (s.player.timeControlStatus != AVPlayerTimeControlStatusPlaying) return;
        double current = CMTimeGetSeconds(time);
        if (isnan(current)) return;
        if (current >= s.endTime) { [s pausePlayer]; return; }
        [s movePlayheadTo:current];
    }];

    CGFloat w = self.view.bounds.size.width;
    CGFloat safeBottom = 34;
    CGFloat bottomY = self.view.bounds.size.height - safeBottom;

    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sendBtn.frame = CGRectMake(kTrackMargin, bottomY - 56, w - kTrackMargin * 2, 50);
    sendBtn.backgroundColor = [UIColor systemBlueColor];
    sendBtn.layer.cornerRadius = 14;
    [sendBtn setTitle:(self.sendButtonTitle ?: SCILocalized(@"Send")) forState:UIControlStateNormal];
    [sendBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sendBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [sendBtn addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sendBtn];

    CGFloat playY = sendBtn.frame.origin.y - 64;
    UIImageSymbolConfiguration *playCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    UIImageSymbolConfiguration *stopCfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];

    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake(w / 2 - 28, playY, 56, 56);
    self.playBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.playBtn.layer.cornerRadius = 28;
    [self.playBtn setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:playCfg] forState:UIControlStateNormal];
    self.playBtn.tintColor = [UIColor whiteColor];
    [self.playBtn addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playBtn];

    self.stopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.stopBtn.frame = CGRectMake(CGRectGetMaxX(self.playBtn.frame) + 16, playY + 8, 40, 40);
    self.stopBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.stopBtn.layer.cornerRadius = 20;
    [self.stopBtn setImage:[UIImage systemImageNamed:@"stop.fill" withConfiguration:stopCfg] forState:UIControlStateNormal];
    self.stopBtn.tintColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    [self.stopBtn addTarget:self action:@selector(stopTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stopBtn];

    self.rangeLabel = [[UILabel alloc] initWithFrame:CGRectMake(kTrackMargin, playY - 36, w - kTrackMargin * 2, 24)];
    self.rangeLabel.textColor = [UIColor whiteColor];
    self.rangeLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium];
    self.rangeLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.rangeLabel];

    CGFloat trackY = self.rangeLabel.frame.origin.y - kTrackH - 20;

    self.trackView = [[UIView alloc] initWithFrame:CGRectMake(kTrackMargin, trackY, w - kTrackMargin * 2, kTrackH)];
    self.trackView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.trackView.layer.cornerRadius = 10;
    self.trackView.clipsToBounds = YES;
    [self.view addSubview:self.trackView];

    [self generateWaveformBars];

    self.selectedRange = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.trackView.bounds.size.width, kTrackH)];
    self.selectedRange.backgroundColor = [UIColor colorWithRed:0.35 green:0.5 blue:1.0 alpha:0.25];
    self.selectedRange.userInteractionEnabled = NO;
    self.selectedRange.layer.cornerRadius = 10;
    [self.trackView addSubview:self.selectedRange];

    self.leftHandle = [[UIView alloc] initWithFrame:CGRectMake(-kHandleHitW / 2, -10, kHandleHitW, kTrackH + 20)];
    self.leftHandle.backgroundColor = [UIColor clearColor];
    self.leftHandle.userInteractionEnabled = YES;
    UIView *leftVisual = [self createHandleVisual];
    leftVisual.frame = CGRectMake((kHandleHitW - kHandleW) / 2, 10, kHandleW, kTrackH);
    leftVisual.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;
    [self.leftHandle addSubview:leftVisual];
    [self.trackView addSubview:self.leftHandle];
    UIPanGestureRecognizer *leftPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(leftHandlePan:)];
    [self.leftHandle addGestureRecognizer:leftPan];

    CGFloat trackW = self.trackView.bounds.size.width;
    self.rightHandle = [[UIView alloc] initWithFrame:CGRectMake(trackW - kHandleHitW / 2, -10, kHandleHitW, kTrackH + 20)];
    self.rightHandle.backgroundColor = [UIColor clearColor];
    self.rightHandle.userInteractionEnabled = YES;
    UIView *rightVisual = [self createHandleVisual];
    rightVisual.frame = CGRectMake((kHandleHitW - kHandleW) / 2, 10, kHandleW, kTrackH);
    rightVisual.layer.maskedCorners = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
    [self.rightHandle addSubview:rightVisual];
    [self.trackView addSubview:self.rightHandle];
    UIPanGestureRecognizer *rightPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rightHandlePan:)];
    [self.rightHandle addGestureRecognizer:rightPan];

    self.playhead = [[UIView alloc] initWithFrame:CGRectMake(0, 2, 2.5, kTrackH - 4)];
    self.playhead.backgroundColor = [UIColor whiteColor];
    self.playhead.layer.cornerRadius = 1.25;
    self.playhead.hidden = YES;
    [self.trackView addSubview:self.playhead];

    CGFloat topY = 70;
    CGFloat topH = trackY - topY - 40;
    if (self.isVideo) {
        self.previewContainer = [[UIView alloc] initWithFrame:CGRectMake(kTrackMargin, topY, w - kTrackMargin * 2, topH)];
        self.previewContainer.backgroundColor = [UIColor blackColor];
        self.previewContainer.layer.cornerRadius = 12;
        self.previewContainer.clipsToBounds = YES;
        [self.view addSubview:self.previewContainer];

        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.frame = self.previewContainer.bounds;
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [self.previewContainer.layer addSublayer:self.playerLayer];
    } else {
        UIImageSymbolConfiguration *iconCfg = [UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIImageSymbolWeightLight];
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform" withConfiguration:iconCfg]];
        icon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.frame = CGRectMake(w / 2 - 24, topY, 48, 48);
        [self.view addSubview:icon];
    }

    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, trackY - 38, w - 40, 18)];
    nameLabel.text = [self.mediaURL lastPathComponent];
    nameLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.4];
    nameLabel.font = [UIFont systemFontOfSize:13];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.view addSubview:nameLabel];

    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, trackY - 20, w - 40, 16)];
    self.durationLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    self.durationLabel.font = [UIFont systemFontOfSize:12];
    self.durationLabel.textAlignment = NSTextAlignmentCenter;
    self.durationLabel.text = [NSString stringWithFormat:SCILocalized(@"Total: %@"), [self formatTime:self.totalDuration]];
    [self.view addSubview:self.durationLabel];

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.frame = CGRectMake(12, 50, 36, 36);
    UIImageSymbolConfiguration *xCfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    [cancelBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:xCfg] forState:UIControlStateNormal];
    cancelBtn.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    cancelBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    cancelBtn.layer.cornerRadius = 18;
    [cancelBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancelBtn];

    [self updateRangeUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.playerLayer && self.previewContainer) {
        self.playerLayer.frame = self.previewContainer.bounds;
    }
}

- (void)generateWaveformBars {
    CGFloat trackW = self.trackView.bounds.size.width;
    int barCount = (int)(trackW / 4);
    CGFloat barW = 2.0;
    CGFloat gap = (trackW - barCount * barW) / (barCount - 1);
    for (int i = 0; i < barCount; i++) {
        CGFloat h = 8 + arc4random_uniform((unsigned int)(kTrackH - 16));
        CGFloat x = i * (barW + gap);
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(x, (kTrackH - h) / 2, barW, h)];
        bar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bar.layer.cornerRadius = 1;
        [self.trackView insertSubview:bar atIndex:0];
    }
}

- (UIView *)createHandleVisual {
    UIView *handle = [[UIView alloc] init];
    handle.backgroundColor = [UIColor systemBlueColor];
    handle.layer.cornerRadius = 4;
    handle.userInteractionEnabled = NO;
    UIView *grip = [[UIView alloc] initWithFrame:CGRectMake(5, kTrackH / 2 - 8, 6, 16)];
    grip.userInteractionEnabled = NO;
    for (int i = 0; i < 2; i++) {
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(i * 4, 0, 1.5, 16)];
        line.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        line.layer.cornerRadius = 0.75;
        [grip addSubview:line];
    }
    [handle addSubview:grip];
    return handle;
}

- (CGFloat)timeToX:(double)time {
    CGFloat trackW = self.trackView.bounds.size.width;
    return (time / self.totalDuration) * trackW;
}

- (double)xToTime:(CGFloat)x {
    CGFloat trackW = self.trackView.bounds.size.width;
    double t = (x / trackW) * self.totalDuration;
    return MAX(0, MIN(t, self.totalDuration));
}

- (void)leftHandlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.trackView];
    [pan setTranslation:CGPointZero inView:self.trackView];
    CGFloat centerX = CGRectGetMidX(self.leftHandle.frame) + translation.x;
    double newTime = [self xToTime:centerX];
    newTime = MAX(0, MIN(newTime, self.endTime - 0.5));
    self.startTime = newTime;
    if (self.maxDurationSecs > 0 && self.endTime - self.startTime > self.maxDurationSecs) {
        self.endTime = self.startTime + self.maxDurationSecs;
    }
    [self updateRangeUI];
}

- (void)rightHandlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.trackView];
    [pan setTranslation:CGPointZero inView:self.trackView];
    CGFloat centerX = CGRectGetMidX(self.rightHandle.frame) + translation.x;
    double newTime = [self xToTime:centerX];
    newTime = MIN(self.totalDuration, MAX(newTime, self.startTime + 0.5));
    if (self.maxDurationSecs > 0 && newTime - self.startTime > self.maxDurationSecs) {
        newTime = self.startTime + self.maxDurationSecs;
    }
    self.endTime = newTime;
    [self updateRangeUI];
}

- (void)updateRangeUI {
    CGFloat leftX = [self timeToX:self.startTime];
    CGFloat rightX = [self timeToX:self.endTime];
    self.leftHandle.frame = CGRectMake(leftX - kHandleHitW / 2, -10, kHandleHitW, kTrackH + 20);
    self.rightHandle.frame = CGRectMake(rightX - kHandleHitW / 2, -10, kHandleHitW, kTrackH + 20);
    self.selectedRange.frame = CGRectMake(leftX, 0, rightX - leftX, kTrackH);
    double sel = self.endTime - self.startTime;
    self.rangeLabel.text = [NSString stringWithFormat:@"%@  —  %@    (%@)",
        [self formatTime:self.startTime], [self formatTime:self.endTime], [self formatDuration:sel]];
}

- (NSString *)formatTime:(double)secs {
    int m = (int)secs / 60;
    int s = (int)secs % 60;
    return [NSString stringWithFormat:@"%d:%02d", m, s];
}

- (NSString *)formatDuration:(double)secs {
    if (secs < 60) return [NSString stringWithFormat:@"%.1fs", secs];
    int m = (int)secs / 60;
    double s = secs - m * 60;
    return [NSString stringWithFormat:@"%dm %.0fs", m, s];
}

- (double)currentPlayerTime {
    double t = CMTimeGetSeconds(self.player.currentTime);
    return (isnan(t) || t < 0) ? self.startTime : t;
}

- (void)movePlayheadTo:(double)t {
    double clamped = MAX(self.startTime, MIN(t, self.endTime));
    CGFloat x = [self timeToX:clamped];
    self.playhead.frame = CGRectMake(x - 1.25, 2, 2.5, kTrackH - 4);
}

- (void)setPlayIcon:(NSString *)name {
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    [self.playBtn setImage:[UIImage systemImageNamed:name withConfiguration:cfg] forState:UIControlStateNormal];
}

- (void)playPauseTapped {
    self.isPlaying ? [self pausePlayer] : [self playFromCurrent];
}

- (void)playFromCurrent {
    if (!self.player) return;
    double pos = [self currentPlayerTime];
    if (pos < self.startTime || pos >= self.endTime - 0.05) pos = self.startTime;
    self.isPlaying = YES;
    self.playhead.hidden = NO;
    [self movePlayheadTo:pos];
    [self setPlayIcon:@"pause.fill"];
    CMTime tol = CMTimeMakeWithSeconds(0.05, 600);
    __weak SCITrimViewController *weakSelf = self;
    [self.player seekToTime:CMTimeMakeWithSeconds(pos, 600)
            toleranceBefore:tol toleranceAfter:tol
          completionHandler:^(BOOL finished) {
        SCITrimViewController *s = weakSelf;
        if (!s || !s.isPlaying) return;
        [s.player play];
    }];
}

- (void)pausePlayer {
    self.isPlaying = NO;
    [self.player pause];
    [self setPlayIcon:@"play.fill"];
}

- (void)stopTapped {
    [self pausePlayer];
    CMTime tol = CMTimeMakeWithSeconds(0.05, 600);
    [self.player seekToTime:CMTimeMakeWithSeconds(self.startTime, 600) toleranceBefore:tol toleranceAfter:tol];
    [self movePlayheadTo:self.startTime];
    self.playhead.hidden = YES;
}

- (void)tearDownPlayer {
    if (self.timeObserver && self.player) [self.player removeTimeObserver:self.timeObserver];
    self.timeObserver = nil;
    [self.player pause];
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    self.player = nil;
    self.isPlaying = NO;
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)deletePreConvertedTempIfAny {
    if ([self.mediaURL isFileURL] &&
        [[self.mediaURL lastPathComponent] hasPrefix:@"rg_pre_"]) {
        [[NSFileManager defaultManager] removeItemAtURL:self.mediaURL error:nil];
    }
}

- (void)cancelTapped {
    [self tearDownPlayer];
    [self deletePreConvertedTempIfAny];
    void (^cb)(void) = self.onCancel;
    [self dismissViewControllerAnimated:YES completion:^{ if (cb) cb(); }];
}

- (void)sendTapped {
    [self tearDownPlayer];
    double dur = self.endTime - self.startTime;
    if (dur < 0.5) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"Selection too short (min 0.5s)")];
        return;
    }
    CMTimeRange trimRange = CMTimeRangeMake(CMTimeMakeWithSeconds(self.startTime, 600), CMTimeMakeWithSeconds(dur, 600));
    void (^cb)(CMTimeRange) = self.onSend;
    [self dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(trimRange);
    }];
}

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

@end
