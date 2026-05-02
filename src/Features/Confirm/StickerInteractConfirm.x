#import "../../Utils.h"
#import <objc/runtime.h>

// Highlights vs stories split by _analyticsModule substring.
static BOOL sciTapIsHighlight(id target) {
    Ivar iv = class_getInstanceVariable(object_getClass(target), "_analyticsModule");
    if (!iv) return NO;
    id v = nil;
    @try { v = object_getIvar(target, iv); } @catch (__unused id e) { return NO; }
    if (![v isKindOfClass:[NSString class]]) return NO;
    return [((NSString *)v).lowercaseString containsString:@"highlight"];
}

static id sciReadIvar(id obj, const char *name) {
    if (!obj || !name) return nil;
    Class c = object_getClass(obj);
    Ivar iv = nil;
    while (c && !iv) {
        iv = class_getInstanceVariable(c, name);
        if (!iv) c = class_getSuperclass(c);
    }
    if (!iv) return nil;
    id v = nil;
    @try { v = object_getIvar(obj, iv); } @catch (__unused id e) {}
    return v;
}

// IGStoryOverlayTapModelObject uses one-ivar-per-sticker-kind.
// Extend to grow "reactions only" scope to polls/sliders/quizzes if needed.
static const char * const kSciReactionIvars[] = {
    "_reactionSticker_reactionStickerDataFragment",
    NULL
};

// IGStoryViewerTapTarget._tappableOverlay._object._tapModelObject.<ivar> non-nil iff reaction.
static BOOL sciTapIsReactionSticker(id target) {
    id overlay = sciReadIvar(target, "_tappableOverlay");
    if (!overlay) return NO;
    id obj = sciReadIvar(overlay, "_object");
    if (!obj) return NO;
    id tapObj = sciReadIvar(obj, "_tapModelObject");
    if (!tapObj) return NO;

    for (const char * const *name = kSciReactionIvars; *name; name++) {
        if (sciReadIvar(tapObj, *name)) return YES;
    }
    return NO;
}

%hook IGStoryViewerTapTarget
- (void)_didTap:(id)arg1 forEvent:(id)arg2 {
    BOOL highlight = sciTapIsHighlight(self);
    NSString *mode = [SCIUtils getStringPref:highlight ? @"sticker_interact_highlights_mode"
                                                       : @"sticker_interact_stories_mode"];
    if (!mode.length || [mode isEqualToString:@"off"]) return %orig;
    if ([mode isEqualToString:@"reactions"] && !sciTapIsReactionSticker(self)) return %orig;

    NSString *title = highlight ? SCILocalized(@"Confirm sticker interaction (highlights)")
                                : SCILocalized(@"Confirm sticker interaction (stories)");
    [SCIUtils showConfirmation:^(void) { %orig; } title:title];
}
%end
