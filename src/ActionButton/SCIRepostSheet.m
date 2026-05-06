#import "SCIRepostSheet.h"
#import "../Utils.h"
#import "../Downloader/Download.h"
#import "../PhotoAlbum.h"
#import <Photos/Photos.h>

@implementation SCIRepostSheet

+ (void)repostWithVideoURL:(NSURL *)videoURL photoURL:(NSURL *)photoURL {
    NSURL *url = videoURL ?: photoURL;
    if (!url) { [SCIUtils showErrorHUDWithDescription:SCILocalized(@"No media URL")]; return; }

    // Show pill
    SCIDownloadPillView *pill = [SCIDownloadPillView shared];
    [pill resetState];
    [pill setText:SCILocalized(@"Preparing repost...")];
    [pill setSubtitle:nil];
    UIView *hostView = [UIApplication sharedApplication].keyWindow ?: topMostController().view;
    if (hostView) [pill showInView:hostView];

    // Download to temp file
    NSString *ext = [[url lastPathComponent] pathExtension];
    if (!ext.length) ext = videoURL ? @"mp4" : @"jpg";
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"repost_%@.%@", [[NSUUID UUID] UUIDString], ext]];

    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession]
        downloadTaskWithURL:url completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *err) {
        if (err || !loc) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [pill showError:SCILocalized(@"Download failed")];
                [pill dismissAfterDelay:2.0];
            });
            return;
        }

        NSError *mv = nil;
        NSURL *fileURL = [NSURL fileURLWithPath:tmp];
        [[NSFileManager defaultManager] moveItemAtURL:loc toURL:fileURL error:&mv];
        if (mv) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [pill showError:SCILocalized(@"Save failed")];
                [pill dismissAfterDelay:2.0];
            });
            return;
        }

        // Save to Photos and get the localIdentifier
        [self saveToPhotosAndOpenCreation:fileURL isVideo:(videoURL != nil) pill:pill];
    }];
    [task resume];
}

+ (void)saveToPhotosAndOpenCreation:(NSURL *)fileURL isVideo:(BOOL)isVideo pill:(SCIDownloadPillView *)pill {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [pill showError:SCILocalized(@"Photos access denied")];
                [pill dismissAfterDelay:2.0];
            });
            return;
        }

        __block NSString *localId = nil;

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *req;
            if (isVideo) {
                req = [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            } else {
                UIImage *img = [UIImage imageWithContentsOfFile:fileURL.path];
                if (img) {
                    req = [PHAssetCreationRequest creationRequestForAssetFromImage:img];
                } else {
                    req = [PHAssetCreationRequest creationRequestForAsset];
                    PHAssetResourceCreationOptions *opts = [PHAssetResourceCreationOptions new];
                    opts.shouldMoveFile = YES;
                    [req addResourceWithType:PHAssetResourceTypePhoto fileURL:fileURL options:opts];
                }
            }
            localId = req.placeholderForCreatedAsset.localIdentifier;
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success || !localId.length) {
                    [pill showError:SCILocalized(@"Failed to save")];
                    [pill dismissAfterDelay:2.0];
                    return;
                }

                // File the new asset into RyukGram album when the pref is on.
                // Fire-and-forget — the IG creator handoff doesn't depend on it.
                if ([SCIUtils getBoolPref:@"save_to_ryukgram_album"]) {
                    [SCIPhotoAlbum addAssetWithLocalIdentifier:localId completion:nil];
                }

                [pill showSuccess:SCILocalized(@"Opening creator...")];
                [pill dismissAfterDelay:1.0];

                // Open IG's native creation flow with the saved asset
                NSString *urlStr = [NSString stringWithFormat:@"instagram://library?LocalIdentifier=%@",
                                    [localId stringByAddingPercentEncodingWithAllowedCharacters:
                                     [NSCharacterSet URLQueryAllowedCharacterSet]]];
                NSURL *igURL = [NSURL URLWithString:urlStr];
                if ([[UIApplication sharedApplication] canOpenURL:igURL]) {
                    [[UIApplication sharedApplication] openURL:igURL options:@{} completionHandler:nil];
                } else {
                    // Fallback: show share sheet
                    [SCIUtils showShareVC:fileURL];
                }
            });
        }];
    }];
}

@end
