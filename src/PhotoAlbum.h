// Dedicated "RyukGram" album in the Photos library. Created on first use.

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@interface SCIPhotoAlbum : NSObject

+ (NSString *)albumName;
+ (void)fetchOrCreateAlbumWithCompletion:(void (^)(PHAssetCollection *album, NSError *error))completion;

/// Saves fileURL into the album. Treats as photo or video by extension.
+ (void)saveFileToAlbum:(NSURL *)fileURL completion:(void (^)(BOOL success, NSError *error))completion;

/// One-shot photo-library observer that re-files the next inserted asset into
/// the album. Use to capture saves done via UIActivityViewController's
/// "Save to Photos" activity. Auto-unregisters after first capture or 60s.
+ (void)watchForNextSavedAsset;

/// No-op when `save_to_ryukgram_album` is off. Call before any share-sheet
/// present so "Save Video / Save Image" picks route into the album.
+ (void)armWatcherIfEnabled;

/// Adds an existing PHAsset (by localIdentifier) to the album. Use when the
/// caller needs the localIdentifier preserved (e.g. repost handoff to IG).
+ (void)addAssetWithLocalIdentifier:(NSString *)localId
                         completion:(void (^)(BOOL success, NSError *error))completion;

@end
