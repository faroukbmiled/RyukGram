// SCIProfileHelpers — single source of truth for "look up the user that owns
// the current profile page", "fetch the HD profile picture", and "share/save
// a profile picture with proper download retention". Backed by hooks on
// IGProfileViewController that maintain a cheap (VC pointer → IGUser*)
// registry so we don't ivar-walk responders on every menu build.
//
// All public methods are safe to call when no profile is active — they return
// nil / no-op gracefully. All methods read the latest profile user lazily; no
// stale captures.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIProfileHelpers : NSObject

// MARK: - Active profile registry (called by hooks; not for clients)

+ (void)registerProfileVC:(UIViewController *)vc user:(nullable id)user;
+ (void)unregisterProfileVC:(UIViewController *)vc;

// MARK: - Lookup

// Walk responder chain to the nearest IGProfileViewController and return the
// IGUser registered for it. Skips ivar reflection.
+ (nullable id)userForView:(UIView *)view;
+ (nullable id)userForViewController:(UIViewController *)vc;

// Topmost registered profile VC (most-recently-shown).
+ (nullable UIViewController *)activeProfileViewController;

// MARK: - User accessors (KVC, no reflection)

+ (nullable NSString *)usernameForUser:(id)user;
+ (nullable NSString *)pkForUser:(id)user;
+ (nullable NSString *)fullNameForUser:(id)user;
+ (nullable NSString *)biographyForUser:(id)user;
+ (nullable NSURL *)profileLinkForUser:(id)user;

// Privacy: returns 1 (public) / 2 (private) / nil (unknown).
+ (nullable NSNumber *)privacyStatusForUser:(id)user;
+ (nullable NSNumber *)followerCountForUser:(id)user;
+ (nullable NSNumber *)followingCountForUser:(id)user;

// MARK: - Picture URL

// The fastest URL we have right now (KVC/fieldCache). May be a low-res IG CDN
// URL. Returns nil only when nothing is reachable.
+ (nullable NSURL *)cachedPictureURLForUser:(id)user;

// Hits /api/v1/users/{pk}/info/ and resolves the largest hd_profile_pic_url.
// Calls back on the main queue. If the API fails or no PK is available, falls
// back to cachedPictureURLForUser:.
+ (void)resolveHDPictureURLForUser:(id)user
                          completion:(void(^)(NSURL * _Nullable url))completion;

// MARK: - Caption

// "Full Name\n@username\n\nbio" — the same caption used by the profile-photo
// long-press zoom path.
+ (nullable NSString *)captionForUser:(id)user;

// MARK: - Actions (delegate retained internally)

// Open the profile picture in SCIMediaViewer. Fetches HD if available, falls
// back to whatever URL the IGUser already has.
+ (void)viewPictureForUser:(id)user;

// Download the HD URL and present iOS share sheet.
+ (void)sharePictureForUser:(id)user;

// Download the HD URL and save to Photos. Honors `gallery_save_mode` for
// optional mirroring into the RyukGram gallery.
+ (void)savePictureForUser:(id)user;

// Download the HD URL and save into the RyukGram gallery only.
+ (void)savePictureToGalleryForUser:(id)user;

@end

NS_ASSUME_NONNULL_END
