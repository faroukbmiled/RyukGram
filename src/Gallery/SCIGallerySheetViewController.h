// Reusable bottom-sheet base for the gallery's pickers (Sort, Filter). Not
// backed by UISheetPresentationController — we ship a custom card so iOS 26's
// translucent sheet material can't bleed in. Always opaque, always grey,
// configurable height per subclass.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIGallerySheetViewController : UIViewController

@property (nonatomic, copy) NSString *sheetTitle;

@property (nonatomic, strong, readonly) UIView *card;
@property (nonatomic, strong, readonly) UIScrollView *scrollView;
@property (nonatomic, strong, readonly) UIStackView *contentStack;

/// Subclasses override to control the card's compact (initial) height.
/// User can pan up to grow it up to maxCardHeight. Default = 430pt clamped
/// to 60% screen.
- (CGFloat)preferredCardHeight;

/// Maximum card height when user drags up. Default = 92% screen.
- (CGFloat)maxCardHeight;

/// Animate the card down + dismiss. Subclasses call this when the user
/// commits a selection so the dismissal matches our custom present animation.
- (void)dismissAnimated;

- (void)addSectionTitle:(NSString *)title;
- (void)addCardRow:(UIView *)row;
- (void)addContentView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
