// Bypass DM char limit — IGDirectComposer caps message length via the
// _characterLimit ivar (q, signed long long). We overwrite it with LLONG_MAX
// from the entry points where IG would consult it for input/send checks.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>

static inline BOOL sciBypassEnabled(void) {
    return [SCIUtils getBoolPref:@"bypass_dm_char_limit"];
}

static void sciBumpCharacterLimit(id composer) {
    if (!composer) return;
    static Ivar sCharLimitIvar = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = NSClassFromString(@"IGDirectComposer");
        if (cls) sCharLimitIvar = class_getInstanceVariable(cls, "_characterLimit");
    });
    if (!sCharLimitIvar) return;
    long long *slot = (long long *)((uintptr_t)(__bridge void *)composer + (uintptr_t)ivar_getOffset(sCharLimitIvar));
    if (*slot != LLONG_MAX) *slot = LLONG_MAX;
}

%hook IGDirectComposer

- (void)didMoveToWindow {
    %orig;
    if (sciBypassEnabled() && self.window) sciBumpCharacterLimit(self);
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if (sciBypassEnabled()) sciBumpCharacterLimit(self);
    return %orig;
}

- (void)textViewDidChange:(UITextView *)textView {
    if (sciBypassEnabled()) sciBumpCharacterLimit(self);
    %orig;
}

%end
