// Confirm like + emoji quick-reaction on opened notes (reply-to-author screen).

#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

typedef void (*SciVoidFn)(id, SEL);
typedef void (*SciTap1Fn)(id, SEL, id);

static SciVoidFn orig_composerLike  = NULL;
static SciTap1Fn orig_emojiQuickTap = NULL;

static void new_composerLike(id self, SEL _cmd) {
    if (![SCIUtils getBoolPref:@"note_like_confirm"]) { orig_composerLike(self, _cmd); return; }
    __strong id sSelf = self;
    [SCIUtils showConfirmation:^{
        @try { orig_composerLike(sSelf, _cmd); }
        @catch (__unused id e) {}
    } title:SCILocalized(@"Confirm note like")];
}

// IGDirectComposer is shared across DMs / story reply / reels reply etc.
// Scope to notes via the composer's button delegate class.
static BOOL sciComposerHostedByNotes(id composer) {
    @try {
        id d = [composer valueForKey:@"buttonDelegate"];
        return [d isKindOfClass:NSClassFromString(@"IGDirectReplyToAuthorComposerViewController")];
    } @catch (__unused id e) { return NO; }
}

static void new_emojiQuickTap(id self, SEL _cmd, id button) {
    if (![SCIUtils getBoolPref:@"note_react_confirm"] || !sciComposerHostedByNotes(self)) {
        orig_emojiQuickTap(self, _cmd, button);
        return;
    }
    __strong id sSelf = self;
    __strong id sBtn = button;
    [SCIUtils showConfirmation:^{
        @try { orig_emojiQuickTap(sSelf, _cmd, sBtn); }
        @catch (__unused id e) {}
    } title:SCILocalized(@"Confirm note emoji reaction")];
}

%ctor {
    SEL sComposerLike = NSSelectorFromString(@"didTapLikeButton");
    SEL sEmojiQuick   = NSSelectorFromString(@"_didTapEmojiQuickReactionButton:");

    Class composer = NSClassFromString(@"_TtC26IGDirectReplyToAuthorSwift33IGDirectReplyToAuthorComposerView");
    if (composer && class_getInstanceMethod(composer, sComposerLike))
        MSHookMessageEx(composer, sComposerLike, (IMP)new_composerLike, (IMP *)&orig_composerLike);

    Class igComposer = NSClassFromString(@"IGDirectComposer");
    if (igComposer && class_getInstanceMethod(igComposer, sEmojiQuick))
        MSHookMessageEx(igComposer, sEmojiQuick, (IMP)new_emojiQuickTap, (IMP *)&orig_emojiQuickTap);
}
