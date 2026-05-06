// Photos / Gallery download submenu. Presents a Photos+Gallery action sheet
// when the gallery is enabled, falls through to Photos directly when not.
// Audio routes skip Photos (the library rejects audio).

#import <UIKit/UIKit.h>
#import "../Gallery/SCIGallerySaveMetadata.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIDownloadMenuMode) {
    SCIDownloadMenuModeRemoteURL = 0,
    SCIDownloadMenuModeLocalFile = 1
};

@interface SCIDownloadMenu : NSObject

+ (void)presentForURL:(NSURL *)url
                 mode:(SCIDownloadMenuMode)mode
        fileExtension:(nullable NSString *)fileExtension
             hudLabel:(nullable NSString *)hudLabel
             metadata:(nullable SCIGallerySaveMetadata *)metadata
              isAudio:(BOOL)isAudio
               fromVC:(nullable UIViewController *)fromVC;

// forceTarget: 0 = Photos (default), 1 = Gallery, 2 = Share.
+ (void)downloadURL:(NSURL *)url
      fileExtension:(nullable NSString *)fileExtension
           hudLabel:(nullable NSString *)hudLabel
           metadata:(nullable SCIGallerySaveMetadata *)metadata
        forceTarget:(NSInteger)forceTarget;

+ (NSArray<UIAlertAction *> *)alertActionsForURL:(NSURL *)url
                                            mode:(SCIDownloadMenuMode)mode
                                   fileExtension:(nullable NSString *)fileExtension
                                        hudLabel:(nullable NSString *)hudLabel
                                        metadata:(nullable SCIGallerySaveMetadata *)metadata
                                         isAudio:(BOOL)isAudio
                                     titlePrefix:(nullable NSString *)titlePrefix;

@end

NS_ASSUME_NONNULL_END
