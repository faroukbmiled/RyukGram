// Explore tab hide toggles.
//   hide_explore_grid       → posts grid + shimmer loader
//   hide_trending_searches  → category chip bar + algo button on the right
//
// Grid revealing rules: tapping a chip or focusing the search bar counts as
// engagement and unhides the grid until the user leaves the Explore tab.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>

static BOOL sciHideGrid(void)   { return [SCIUtils getBoolPref:@"hide_explore_grid"]; }
static BOOL sciHideSearch(void) { return [SCIUtils getBoolPref:@"hide_trending_searches"]; }

static __weak UIViewController *gActiveExploreVC = nil;
static BOOL gSearchFocused = NO;
static BOOL gUserEngaged = NO;

// MARK: - Hide helpers

// Alpha + userInteraction instead of .hidden keeps IG's data fetch and the
// shimmer animation alive, so toggling the pref back on shows fresh content
// instantly without a restart.
static void sciSetViewVisuallyHidden(UIView *v, BOOL hidden) {
    if (!v) return;
    v.alpha = hidden ? 0.0 : 1.0;
    v.userInteractionEnabled = !hidden;
}

static void sciSetIvarViewHidden(id host, const char *name, BOOL hidden) {
    Ivar iv = class_getInstanceVariable([host class], name);
    if (!iv) return;
    @try {
        UIView *v = object_getIvar(host, iv);
        if ([v isKindOfClass:[UIView class]]) sciSetViewVisuallyHidden(v, hidden);
    } @catch (__unused id e) {}
}

static void sciApplyExploreHide(id vc) {
    // Chips stay visible while search is focused (they act as filters then).
    BOOL hideChips = sciHideSearch() && !gSearchFocused;
    sciSetIvarViewHidden(vc, "_nidoChipBar", hideChips);

    // Force re-layout so pref flips reflect on re-entry.
    Ivar stvIvar = class_getInstanceVariable([vc class], "_searchTitleView");
    if (stvIvar) {
        @try {
            UIView *tv = object_getIvar(vc, stvIvar);
            if ([tv isKindOfClass:[UIView class]]) {
                [tv setNeedsLayout];
                [tv layoutIfNeeded];
            }
        } @catch (__unused id e) {}
    }

    // Grid reveals on chip tap or search focus.
    BOOL hideGrid = sciHideGrid() && !gUserEngaged && !gSearchFocused;
    sciSetIvarViewHidden(vc, "_shimmeringGridView", hideGrid);

    Ivar gvcIvar = class_getInstanceVariable([vc class], "_gridViewController");
    if (gvcIvar) {
        @try {
            UIViewController *grid = object_getIvar(vc, gvcIvar);
            if ([grid isKindOfClass:[UIViewController class]] && grid.isViewLoaded) {
                sciSetViewVisuallyHidden(grid.view, hideGrid);
                Ivar cvIvar = class_getInstanceVariable([grid class], "_collectionView");
                if (cvIvar) {
                    UIView *cv = object_getIvar(grid, cvIvar);
                    if ([cv isKindOfClass:[UIView class]]) sciSetViewVisuallyHidden(cv, hideGrid);
                }
            }
        } @catch (__unused id e) {}
    }
}

// Algo button vs Cancel: both are IGTapButton siblings of the search bar.
// Cancel has a UIButtonLabel (the "Cancel" text); the algo button is square
// with just an icon child.
static BOOL sciIsAlgoButton(UIView *btn) {
    if (btn.bounds.size.width != btn.bounds.size.height) return NO;
    for (UIView *sub in btn.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) return NO;
    }
    return YES;
}

// MARK: - VC hooks

%group HideExploreGroup

// Subtract the chip bar's height from contentInset.top when chips are hidden,
// so the grid sits flush under the header. Class + ivar lookups are cached.
static Class sciExploreGridVCClass(void) {
    static Class c = Nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = NSClassFromString(@"IGExploreGridViewController"); });
    return c;
}

// Returns the chip bar if `cv` belongs to the explore grid, else nil.
static inline UIView *sciExploreChipBarFor(UIView *cv) {
    Class targetCls = sciExploreGridVCClass();
    if (!targetCls) return nil;
    UIResponder *r = [cv nextResponder];
    while (r && [r class] != targetCls) r = [r nextResponder];
    if (!r) return nil;
    UIViewController *parent = [(UIViewController *)r parentViewController];
    if (!parent) return nil;
    static Ivar cbIvar = NULL;
    static Class parentCls = Nil;
    if (parentCls != [parent class]) {
        parentCls = [parent class];
        cbIvar = class_getInstanceVariable(parentCls, "_nidoChipBar");
    }
    if (!cbIvar) return nil;
    UIView *cb = object_getIvar(parent, cbIvar);
    return [cb isKindOfClass:[UIView class]] ? cb : nil;
}

static inline UIEdgeInsets sciAdjustInset(UIView *cv, UIEdgeInsets inset) {
    if (!sciHideSearch() || gSearchFocused) return inset;
    UIView *cb = sciExploreChipBarFor(cv);
    if (!cb) return inset;
    CGFloat gap = cb.frame.size.height;
    if (gap > 0 && inset.top >= CGRectGetMaxY(cb.frame) - 0.5) {
        inset.top -= gap;
    }
    return inset;
}

%hook IGListCollectionView
- (void)setContentInset:(UIEdgeInsets)inset {
    %orig(sciAdjustInset((UIView *)self, inset));
}
- (void)setScrollIndicatorInsets:(UIEdgeInsets)inset {
    %orig(sciAdjustInset((UIView *)self, inset));
}
%end

%hook IGExploreViewController
- (void)viewDidLayoutSubviews {
    %orig;
    gActiveExploreVC = self;
    sciApplyExploreHide(self);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    gActiveExploreVC = self;
    sciApplyExploreHide(self);
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    gUserEngaged = NO;
    gSearchFocused = NO;
}
- (void)exploreChipBarView:(id)bar didSelectChipAtIndex:(NSInteger)idx {
    %orig;
    gUserEngaged = YES;
    sciApplyExploreHide(self);
    [self.view setNeedsLayout];
}
%end

%hook IGAnimatablePlaceholderTextField
- (BOOL)becomeFirstResponder {
    BOOL r = %orig;
    gSearchFocused = YES;
    if (gActiveExploreVC) {
        sciApplyExploreHide(gActiveExploreVC);
        [gActiveExploreVC.view setNeedsLayout];
    }
    return r;
}
- (BOOL)resignFirstResponder {
    BOOL r = %orig;
    gSearchFocused = NO;
    if (gActiveExploreVC) {
        sciApplyExploreHide(gActiveExploreVC);
        [gActiveExploreVC.view setNeedsLayout];
    }
    return r;
}
%end

// Hook the search title view's own layout — catches every relayout at the
// source, so hiding the algo button + stretching the bar has no lagged frame.
%hook IGExploreSearchTitleView
- (void)layoutSubviews {
    %orig;
    BOOL hide = sciHideSearch();
    Class tapBtnCls = NSClassFromString(@"IGTapButton");
    Class dotCls    = NSClassFromString(@"IGDSDotView");
    Class searchCls = NSClassFromString(@"IGSearchBar");

    UIView *searchBar = nil;
    for (UIView *sub in self.subviews) {
        if (searchCls && [sub isKindOfClass:searchCls]) {
            searchBar = sub;
        } else if (tapBtnCls && [sub isKindOfClass:tapBtnCls] && sciIsAlgoButton(sub)) {
            sub.hidden = hide;
        } else if (dotCls && [sub isKindOfClass:dotCls]) {
            sub.hidden = hide;
        }
    }
    if (searchBar && hide) {
        CGFloat target = self.bounds.size.width;
        if (searchBar.frame.size.width != target) {
            CGRect f = searchBar.frame;
            f.size.width = target;
            searchBar.frame = f;
        }
    }
}
%end

%end // HideExploreGroup

%ctor {
    if ([SCIUtils getBoolPref:@"hide_explore_grid"] ||
        [SCIUtils getBoolPref:@"hide_trending_searches"]) {
        %init(HideExploreGroup);
    }
}
