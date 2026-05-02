// Keep RyukGram's own table-view surfaces visible under the OLED recolor.
// Repaints SCI*-owned cells at SCITheme.surfaceColor (alpha 0.89 dodges the
// recolor gate) on attach.

#import "../../Utils.h"
#import "SCITheme.h"
#import <objc/runtime.h>

static inline BOOL sciOLEDSurfaceInRyukGram(UIView *view) {
    UIResponder *r = view;
    while (r) {
        const char *name = class_getName([r class]);
        if (name && name[0] == 'S' && name[1] == 'C' && name[2] == 'I') return YES;
        r = r.nextResponder;
    }
    return NO;
}

%group OLEDSurfaceGroup

%hook UITableViewCell
- (void)didMoveToSuperview {
    %orig;
    if (!self.superview) return;
    if (![SCITheme shouldRecolor]) return;
    if (!sciOLEDSurfaceInRyukGram((UIView *)self)) return;
    UIColor *tone = [SCITheme surfaceColor];
    UIBackgroundConfiguration *bg = [UIBackgroundConfiguration listGroupedCellConfiguration];
    bg.backgroundColor = tone;
    self.backgroundConfiguration = bg;
    self.backgroundColor = tone;
    self.contentView.backgroundColor = tone;
}
%end

%hook UITableViewHeaderFooterView
- (void)didMoveToSuperview {
    %orig;
    if (!self.superview) return;
    if (![SCITheme shouldRecolor]) return;
    if (!sciOLEDSurfaceInRyukGram((UIView *)self)) return;
    self.backgroundConfiguration = [UIBackgroundConfiguration clearConfiguration];
}
%end

%end

%ctor {
    [SCITheme migrateLegacyPrefs];
    if ([SCITheme mode] == SCIThemeModeOLED) {
        %init(OLEDSurfaceGroup);
    }
}
