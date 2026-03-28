#import "Download.h"
#import <Photos/Photos.h>

#pragma mark - SCIDownloadPillView

@implementation SCIDownloadPillView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
        self.layer.cornerRadius = 20;
        self.clipsToBounds = YES;
        self.alpha = 0;

        // Circular progress (using a small CAShapeLayer ring)
        _progressRing = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressRing.progressTintColor = [UIColor systemBlueColor];
        _progressRing.trackTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
        _progressRing.translatesAutoresizingMaskIntoConstraints = NO;
        _progressRing.layer.cornerRadius = 2;
        _progressRing.clipsToBounds = YES;
        [self addSubview:_progressRing];

        // Text
        _textLabel = [[UILabel alloc] init];
        _textLabel.text = @"Downloading 0%";
        _textLabel.textColor = [UIColor whiteColor];
        _textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_textLabel];

        // Subtitle
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.text = @"Tap to cancel";
        _subtitleLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _subtitleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_subtitleLabel];

        // Tap gesture for cancel
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        [self addGestureRecognizer:tap];

        // Layout:  [progress bar]
        //          [text centered]
        //          [subtitle centered]
        [NSLayoutConstraint activateConstraints:@[
            [_progressRing.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
            [_progressRing.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_progressRing.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_progressRing.heightAnchor constraintEqualToConstant:4],

            [_textLabel.topAnchor constraintEqualToAnchor:_progressRing.bottomAnchor constant:6],
            [_textLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],

            [_subtitleLabel.topAnchor constraintEqualToAnchor:_textLabel.bottomAnchor constant:2],
            [_subtitleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
        ]];
    }
    return self;
}

- (void)handleTap {
    if (self.onCancel) self.onCancel();
}

- (void)showInView:(UIView *)view {
    [self removeFromSuperview];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self];

    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.topAnchor constant:4],
        [self.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [self.widthAnchor constraintGreaterThanOrEqualToConstant:160],
        [self.widthAnchor constraintLessThanOrEqualToConstant:220],
    ]];

    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 1;
    }];
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)dismissAfterDelay:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

- (void)setProgress:(float)progress {
    [self.progressRing setProgress:progress animated:YES];
}

- (void)setText:(NSString *)text {
    self.textLabel.text = text;
}

@end


#pragma mark - SCIDownloadDelegate

@implementation SCIDownloadDelegate

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress {
    self = [super init];

    if (self) {
        _action = action;
        _showProgress = showProgress;
        self.downloadManager = [[SCIDownloadManager alloc] initWithDelegate:self];
    }

    return self;
}

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel {
    // Dismiss any existing pill
    [self.pill dismiss];

    self.pill = [[SCIDownloadPillView alloc] init];

    if (hudLabel) {
        [self.pill setText:hudLabel];
    }

    if (!self.showProgress) {
        self.pill.progressRing.hidden = YES;
        self.pill.subtitleLabel.text = nil;
    }

    __weak typeof(self) weakSelf = self;
    self.pill.onCancel = ^{
        [weakSelf.downloadManager cancelDownload];
    };

    UIViewController *topVC = topMostController();
    UIView *hostView = topVC.view;
    if (!hostView) hostView = [UIApplication sharedApplication].keyWindow;
    if (!hostView) {
        NSLog(@"[SCInsta] Download: No valid view");
        return;
    }
    [self.pill showInView:hostView];

    NSLog(@"[SCInsta] Download: Will start download for url \"%@\" with file extension: \".%@\"", url, fileExtension);
    [self.downloadManager downloadFileWithURL:url fileExtension:fileExtension];
}

- (void)downloadDidStart {
    NSLog(@"[SCInsta] Download: Download started");
}

- (void)downloadDidCancel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pill setText:@"Cancelled"];
        self.pill.subtitleLabel.text = nil;
        self.pill.progressRing.hidden = YES;
        [self.pill dismissAfterDelay:0.8];
    });
    NSLog(@"[SCInsta] Download: Download cancelled");
}

- (void)downloadDidProgress:(float)progress {
    if (self.showProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.pill setProgress:progress];
            [self.pill setText:[NSString stringWithFormat:@"Downloading %d%%", (int)(progress * 100)]];
        });
    }
}

- (void)downloadDidFinishWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error && error.code != NSURLErrorCancelled) {
            NSLog(@"[SCInsta] Download: Download failed with error: \"%@\"", error);
            [self.pill setText:@"Download failed"];
            self.pill.subtitleLabel.text = nil;
            self.pill.progressRing.hidden = YES;
            [self.pill dismissAfterDelay:2.0];
        }
    });
}

- (void)downloadDidFinishWithFileURL:(NSURL *)fileURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pill dismiss];

        NSLog(@"[SCInsta] Download: Finished with url: \"%@\"", [fileURL absoluteString]);

        switch (self.action) {
            case share:
                [SCIUtils showShareVC:fileURL];
                break;

            case quickLook:
                [SCIUtils showQuickLookVC:@[fileURL]];
                break;

            case saveToPhotos: {
                [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                    if (status != PHAuthorizationStatusAuthorized) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [SCIUtils showErrorHUDWithDescription:@"Photo library access denied"];
                        });
                        return;
                    }

                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        NSString *ext = [[fileURL pathExtension] lowercaseString];
                        BOOL isVideo = [@[@"mp4", @"mov", @"m4v"] containsObject:ext];

                        if (isVideo) {
                            PHAssetCreationRequest *req = [PHAssetCreationRequest creationRequestForAsset];
                            PHAssetResourceCreationOptions *opts = [[PHAssetResourceCreationOptions alloc] init];
                            opts.shouldMoveFile = YES;
                            [req addResourceWithType:PHAssetResourceTypeVideo fileURL:fileURL options:opts];
                            req.creationDate = [NSDate date];
                        } else {
                            PHAssetCreationRequest *req = [PHAssetCreationRequest creationRequestForAsset];
                            PHAssetResourceCreationOptions *opts = [[PHAssetResourceCreationOptions alloc] init];
                            opts.shouldMoveFile = YES;
                            [req addResourceWithType:PHAssetResourceTypePhoto fileURL:fileURL options:opts];
                            req.creationDate = [NSDate date];
                        }
                    } completionHandler:^(BOOL success, NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (success) {
                                SCIDownloadPillView *donePill = [[SCIDownloadPillView alloc] init];
                                donePill.progressRing.hidden = YES;
                                donePill.subtitleLabel.text = nil;
                                [donePill setText:@"Saved to Photos"];
                                UIView *hostView = topMostController().view;
                                if (hostView) {
                                    [donePill showInView:hostView];
                                    [donePill dismissAfterDelay:1.5];
                                }
                            } else {
                                [SCIUtils showErrorHUDWithDescription:@"Failed to save to Photos"];
                            }
                        });
                    }];
                }];
                break;
            }
        }
    });
}

@end
