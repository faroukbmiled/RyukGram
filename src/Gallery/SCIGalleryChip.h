// Shared chip component used across the gallery's sort + filter sheets. Auto-
// sizes to fit its label via UIButtonConfiguration, so long titles never
// truncate against fixed widths.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryChip : UIButton

@property (nonatomic, assign, getter=isOnState) BOOL onState;

+ (instancetype)chipWithTitle:(NSString *)title
                       symbol:(nullable NSString *)sfSymbol;

/// Smaller chip — tighter padding + 12pt font. Used for high-density rows
/// like the username scroll strip in the filter sheet.
+ (instancetype)compactChipWithTitle:(NSString *)title
                              symbol:(nullable NSString *)sfSymbol;

- (void)setOnState:(BOOL)on animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
