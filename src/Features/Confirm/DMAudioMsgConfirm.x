#import "../../Utils.h"

// Legacy hook (pre AI voices interface)
%hook IGDirectThreadViewController
- (void)voiceRecordViewController:(id)arg1 didRecordAudioClipWithURL:(id)arg2 waveform:(id)arg3 duration:(CGFloat)arg4 entryPoint:(NSInteger)arg5 {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm voice messages")];
    } else {
        return %orig;
    }
}
%end

// Long press recording auto-sends — swallow the tap while confirm is on.
%hook IGDirectComposer
- (void)_didLongPressVoiceMessage:(id)arg1 {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        return;
    } else {
        return %orig;
    }
}
%end

// Demangled name: IGDirectAIVoiceUIKit.CompactBarContentView
%hook _TtC20IGDirectAIVoiceUIKitP33_5754F7617E0D924F9A84EFA352BBD29A21CompactBarContentView
- (void)didTapSend {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        [SCIUtils showConfirmation:^(void) { %orig; } title:SCILocalized(@"Confirm voice messages")];
    } else {
        return %orig;
    }
}
%end
