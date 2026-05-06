// SCIMediaActions — shared media extraction + action handlers for the action menu.

#import <UIKit/UIKit.h>
#import "../InstagramHeaders.h"
#import "../Downloader/Download.h"
#import "SCIActionMenu.h"

NS_ASSUME_NONNULL_BEGIN

/// Where the action is being invoked from. Used to target settings entries
/// and to pick context-specific language in HUDs.
typedef NS_ENUM(NSInteger, SCIActionContext) {
    SCIActionContextFeed,
    SCIActionContextReels,
    SCIActionContextStories,
};

@interface SCIMediaActions : NSObject

// MARK: - Filename naming

// `@username_context_yyyyMMdd_HHmmss` (sanitized). UUID fallback on failure.
+ (NSString *)filenameStemForMedia:(nullable id)media contextLabel:(NSString *)ctxLabel;

// Same shape, raw inputs — for features without an IGMedia (DM voice, notes,
// disappearing media). Empty username falls back to "media".
+ (NSString *)filenameStemForUsername:(nullable NSString *)username
                          contextLabel:(NSString *)ctxLabel;

// "feed" / "reels" / "stories".
+ (NSString *)contextLabelForContext:(SCIActionContext)ctx;

// Stem read by the download + mux write sites to name output files.
+ (nullable NSString *)currentFilenameStem;
+ (void)setCurrentFilenameStem:(nullable NSString *)stem;

// MARK: - Media extraction

/// Return the post's caption string. Tries selectors first, falls back to
/// reading `_fieldCache[@"caption"][@"text"]`.
+ (nullable NSString *)captionForMedia:(id)media;

/// YES if the media is a carousel (multi-photo/video sidecar).
+ (BOOL)isCarouselMedia:(id)media;

/// Ordered children of a carousel IGMedia. Empty array for non-carousels.
+ (NSArray *)carouselChildrenForMedia:(id)media;

/// YES if the media has an audio track (`has_audio` fieldCache == 1).
+ (BOOL)mediaHasAudio:(id)media;

/// Download the raw photo URL, skipping any video route.
+ (void)downloadPhotoOnlyForMedia:(id)media action:(DownloadAction)action;

/// Extract the audio-only track from the DASH manifest via FFmpeg. Photos
/// library can't hold audio, so both actions end at the share sheet.
+ (void)downloadAudioOnlyForMedia:(id)media action:(DownloadAction)action;

/// Best URL for a single (non-carousel) media item. Prefers video URL, falls
/// back to photo URL. Returns nil if nothing extractable.
+ (nullable NSURL *)bestURLForMedia:(id)media;

/// Cover/poster image URL for a video-type media (first frame). Works for
/// reels, feed videos, and story videos.
+ (nullable NSURL *)coverURLForMedia:(id)media;

// MARK: - Primary actions (each directly triggerable from a menu entry)

/// Present the media in the native QLPreview UI. Video URLs download first,
/// images preview directly. Optional caption is shown as a subtitle.
+ (void)expandMedia:(id)media
        fromView:(UIView *)sourceView
         caption:(nullable NSString *)caption;

/// Download the best URL for the media and hand off via share sheet.
+ (void)downloadAndShareMedia:(id)media;

/// Download the best URL for the media and save to Photos (respects album pref).
+ (void)downloadAndSaveMedia:(id)media;

/// Download the best URL and save to the RyukGram gallery only (skips Photos).
+ (void)downloadAndSaveMediaToGallery:(id)media fromView:(nullable UIView *)sourceView;

/// Copy the direct CDN URL for the media to the clipboard.
+ (void)copyURLForMedia:(id)media;

/// Copy the post caption to the clipboard.
+ (void)copyCaptionForMedia:(id)media;

/// Trigger Instagram's native repost flow for the given context's currently
/// visible UFI bar. Uses the existing button ivars to avoid reimplementing.
+ (void)triggerRepostForContext:(SCIActionContext)ctx sourceView:(UIView *)sourceView;

/// Open the RyukGram settings page for the given context.
+ (void)openSettingsForContext:(SCIActionContext)ctx fromView:(UIView *)sourceView;

// MARK: - Carousel bulk actions

/// Download every child of a carousel and share as a batch.
+ (void)downloadAllAndShareMedia:(id)carouselMedia;

/// Download every child of a carousel and save to Photos.
+ (void)downloadAllAndSaveMedia:(id)carouselMedia;

/// Download every child of a carousel and copy each one into the RyukGram
/// gallery (skips Photos). Honors source from `ctx`.
+ (void)downloadAllAndSaveMediaToGallery:(id)carouselMedia context:(SCIActionContext)ctx;

/// Save an array of already-downloaded local file URLs into the gallery,
/// updating the shared download pill with per-file progress. Per-file
/// metadata array is optional; falls back to defaultMetadata when shorter.
+ (void)bulkSaveFilesToGallery:(NSArray<NSURL *> *)files
                  perFileMetadata:(nullable NSArray<id> *)perFileMetadata
                  defaultMetadata:(nullable id)defaultMetadata;

/// Copy newline-joined CDN URLs for every child of a carousel.
+ (void)copyAllURLsForMedia:(id)carouselMedia;

// MARK: - Menu builders

// MARK: - Bulk URL download helpers

/// Download an array of URLs in parallel, show pill, call done with file URLs.
+ (void)bulkDownloadURLs:(NSArray<NSURL *> *)urls
                   title:(NSString *)title
                    done:(void(^)(NSArray<NSURL *> *fileURLs))done;

/// Save an array of local file URLs to Photos (sequential, respects album pref).
+ (void)bulkSaveFiles:(NSArray<NSURL *> *)files;

/// Build the full action menu for the given context + media + default tap.
/// If `defaultTap` is provided and non-menu, the builder may reorder or skip
/// its matching leaf so it's visible in the full menu.
+ (NSArray<SCIAction *> *)actionsForContext:(SCIActionContext)ctx
                                      media:(nullable id)media
                                   fromView:(UIView *)sourceView;

/// Build the menu for `ctx`/`media`/`sourceView` and fire the handler whose
/// SCIAction.actionID matches `aid`. Returns YES if a handler ran. Used by
/// the action button's default-tap path so we don't duplicate dispatch logic.
+ (BOOL)executeActionForContext:(SCIActionContext)ctx
                       actionID:(NSString *)aid
                          media:(nullable id)media
                       fromView:(UIView *)sourceView;

@end

NS_ASSUME_NONNULL_END
