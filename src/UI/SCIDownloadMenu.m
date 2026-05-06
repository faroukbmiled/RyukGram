#import "SCIDownloadMenu.h"
#import "../Utils.h"
#import "../InstagramHeaders.h"
#import "../Downloader/Download.h"
#import "../Gallery/SCIGalleryFile.h"
#import <Photos/Photos.h>

// SCIDownloadManager.delegate is weak — local SCIDownloadDelegate references
// are released the moment the calling block returns. Park them in this set
// until the URLSession callbacks have fired.
static NSMutableSet<SCIDownloadDelegate *> *SCIPendingDelegates(void) {
    static NSMutableSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ set = [NSMutableSet new]; });
    return set;
}

static void SCIRetainDelegate(SCIDownloadDelegate *dl) {
    if (!dl) return;
    @synchronized(SCIPendingDelegates()) { [SCIPendingDelegates() addObject:dl]; }
}

static void SCIReleaseDelegateAfter(SCIDownloadDelegate *dl, NSTimeInterval delay) {
    if (!dl) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @synchronized(SCIPendingDelegates()) { [SCIPendingDelegates() removeObject:dl]; }
    });
}

@implementation SCIDownloadMenu

#pragma mark - Helpers

+ (BOOL)galleryEnabled {
    return [SCIUtils getBoolPref:@"sci_gallery_enabled"];
}

+ (void)savePhotosLocal:(NSURL *)fileURL hudLabel:(NSString *)hudLabel metadata:(SCIGallerySaveMetadata *)metadata {
    SCIDownloadDelegate *dl = [[SCIDownloadDelegate alloc] initWithAction:saveToPhotos showProgress:NO];
    dl.pendingGallerySaveMetadata = metadata;
    SCIDownloadPillView *pill = SCIDownloadPillView.shared;
    dl.pill = pill;
    dl.ticketId = [pill beginTicketWithTitle:hudLabel ?: SCILocalized(@"Saving...") onCancel:nil];
    SCIRetainDelegate(dl);
    [dl downloadDidFinishWithFileURL:fileURL];
    SCIReleaseDelegateAfter(dl, 2.0);
}

+ (void)saveGalleryLocal:(NSURL *)fileURL hudLabel:(NSString *)hudLabel metadata:(SCIGallerySaveMetadata *)metadata {
    SCIDownloadDelegate *dl = [[SCIDownloadDelegate alloc] initWithAction:saveToGallery showProgress:NO];
    dl.pendingGallerySaveMetadata = metadata;
    SCIDownloadPillView *pill = SCIDownloadPillView.shared;
    dl.pill = pill;
    dl.ticketId = [pill beginTicketWithTitle:hudLabel ?: SCILocalized(@"Saving...") onCancel:nil];
    SCIRetainDelegate(dl);
    [dl downloadDidFinishWithFileURL:fileURL];
    SCIReleaseDelegateAfter(dl, 2.0);
}

#pragma mark - Remote

+ (void)downloadRemote:(NSURL *)url
         fileExtension:(NSString *)ext
              hudLabel:(NSString *)hudLabel
              metadata:(SCIGallerySaveMetadata *)metadata
                action:(DownloadAction)action {
    SCIDownloadDelegate *dl = [[SCIDownloadDelegate alloc] initWithAction:action showProgress:YES];
    dl.pendingGallerySaveMetadata = metadata;
    SCIRetainDelegate(dl);
    [dl downloadFileWithURL:url fileExtension:(ext.length ? ext : @"bin") hudLabel:hudLabel];
    SCIReleaseDelegateAfter(dl, 180.0);
}

#pragma mark - Public

+ (void)downloadURL:(NSURL *)url
      fileExtension:(NSString *)fileExtension
           hudLabel:(NSString *)hudLabel
           metadata:(SCIGallerySaveMetadata *)metadata
        forceTarget:(NSInteger)forceTarget {
    DownloadAction action = saveToPhotos;
    if (forceTarget == 1) action = saveToGallery;
    else if (forceTarget == 2) action = share;
    [self downloadRemote:url fileExtension:fileExtension hudLabel:hudLabel metadata:metadata action:action];
}

+ (NSArray<UIAlertAction *> *)alertActionsForURL:(NSURL *)url
                                            mode:(SCIDownloadMenuMode)mode
                                   fileExtension:(NSString *)fileExtension
                                        hudLabel:(NSString *)hudLabel
                                        metadata:(SCIGallerySaveMetadata *)metadata
                                         isAudio:(BOOL)isAudio
                                     titlePrefix:(NSString *)titlePrefix {
    NSMutableArray *actions = [NSMutableArray array];
    NSString *prefix = titlePrefix.length ? titlePrefix : SCILocalized(@"Download");

    if (!isAudio) {
        [actions addObject:[UIAlertAction actionWithTitle:prefix
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *_) {
            if (mode == SCIDownloadMenuModeLocalFile) {
                [self savePhotosLocal:url hudLabel:hudLabel metadata:metadata];
            } else {
                [self downloadRemote:url fileExtension:fileExtension hudLabel:hudLabel metadata:metadata action:saveToPhotos];
            }
        }]];
    }

    NSString *galleryTitle = [NSString stringWithFormat:@"%@ %@", prefix, SCILocalized(@"to Gallery")];
    [actions addObject:[UIAlertAction actionWithTitle:galleryTitle
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *_) {
        if (mode == SCIDownloadMenuModeLocalFile) {
            [self saveGalleryLocal:url hudLabel:hudLabel metadata:metadata];
        } else {
            [self downloadRemote:url fileExtension:fileExtension hudLabel:hudLabel metadata:metadata action:saveToGallery];
        }
    }]];

    if (isAudio) {
        [actions addObject:[UIAlertAction actionWithTitle:SCILocalized(@"Share")
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *_) {
            if (mode == SCIDownloadMenuModeLocalFile) {
                [SCIUtils showShareVC:url];
            } else {
                [self downloadRemote:url fileExtension:fileExtension hudLabel:hudLabel metadata:metadata action:share];
            }
        }]];
    }

    return actions;
}

+ (void)presentForURL:(NSURL *)url
                 mode:(SCIDownloadMenuMode)mode
        fileExtension:(NSString *)fileExtension
             hudLabel:(NSString *)hudLabel
             metadata:(SCIGallerySaveMetadata *)metadata
              isAudio:(BOOL)isAudio
               fromVC:(UIViewController *)fromVC {
    BOOL galleryOn = [self galleryEnabled];

    // Gallery off → no submenu. Photos for non-audio (mirror branch in
    // SCIDownloadDelegate still logs to gallery when `gallery_save_mode` is
    // mirror), share fallback for audio.
    if (!galleryOn) {
        if (isAudio) {
            if (mode == SCIDownloadMenuModeLocalFile) [SCIUtils showShareVC:url];
            else [self downloadRemote:url fileExtension:fileExtension hudLabel:hudLabel metadata:metadata action:share];
        } else {
            if (mode == SCIDownloadMenuModeLocalFile) [self savePhotosLocal:url hudLabel:hudLabel metadata:metadata];
            else [self downloadRemote:url fileExtension:fileExtension hudLabel:hudLabel metadata:metadata action:saveToPhotos];
        }
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:hudLabel ?: SCILocalized(@"Download")
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];
    for (UIAlertAction *a in [self alertActionsForURL:url
                                                  mode:mode
                                         fileExtension:fileExtension
                                              hudLabel:hudLabel
                                              metadata:metadata
                                               isAudio:isAudio
                                           titlePrefix:SCILocalized(@"Download")]) {
        [sheet addAction:a];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *presenter = fromVC ?: topMostController();
    [presenter presentViewController:sheet animated:YES completion:nil];
}

@end
