// Replace IG's near-black surfaces with pure black under OLED mode.
// RyukGram's own surfaces opt out via SCIOLEDSurface.xm.

#import "../../Utils.h"
#import "SCITheme.h"

%group OLEDRecolorGroup

%hook UIView
- (void)setBackgroundColor:(UIColor *)color {
    if (![SCITheme shouldRecolor]) { %orig; return; }
    if ([SCITheme colorIsNearBlack:color]) {
        %orig([SCITheme backgroundColor]);
        return;
    }
    %orig;
}
%end

%hook CAGradientLayer
- (void)setColors:(NSArray *)colors {
    if (![SCITheme shouldRecolor]) { %orig; return; }
    if (colors.count >= 1) {
        BOOL allDark = YES;
        for (id raw in colors) {
            CGColorRef cg = (__bridge CGColorRef)raw;
            if (!cg) { allDark = NO; break; }
            UIColor *c = [UIColor colorWithCGColor:cg];
            if (![SCITheme colorIsNearBlack:c]) { allDark = NO; break; }
        }
        if (allDark) {
            id replacement = (id)[SCITheme backgroundColor].CGColor;
            NSMutableArray *flat = [NSMutableArray arrayWithCapacity:colors.count];
            for (NSUInteger i = 0; i < colors.count; i++) [flat addObject:replacement];
            %orig(flat);
            return;
        }
    }
    %orig;
}
%end

%end

%ctor {
    [SCITheme migrateLegacyPrefs];
    // Init unconditionally — the per-call gate handles trait changes at runtime.
    if ([SCITheme mode] == SCIThemeModeOLED) {
        %init(OLEDRecolorGroup);
    }
}
