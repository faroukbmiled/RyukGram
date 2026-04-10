#import "../../Utils.h"

%hook IGSundialPlaybackControlsTestConfiguration
- (id)initWithLauncherSet:(id)set
                     tapToPauseEnabled:(_Bool)tapPauseEnabled
      combineSingleTapPlaybackControls:(_Bool)controls
        isVideoPreviewThumbnailEnabled:(_Bool)previewThumbEnabled
                minScrubberDurationSec:(long long)minSec
         seekResumeScrubberCooldownSec:(double)seekSec
          tapResumeScrubberCooldownSec:(double)tapSec
    persistentScrubberMinVideoDuration:(long long)duration
        isScrubberForShortVideoEnabled:(_Bool)shortScrubberEnabled
{
    _Bool userTapPauseEnabled = tapPauseEnabled;
    if ([[SCIUtils getStringPref:@"reels_tap_control"] isEqualToString:@"pause"]) userTapPauseEnabled = true;
    else if ([[SCIUtils getStringPref:@"reels_tap_control"] isEqualToString:@"mute"]) userTapPauseEnabled = false;

    long long userMinSec = minSec;
    long long userDuration = duration;
    _Bool userShortScrubberEnabled = shortScrubberEnabled;
    if ([SCIUtils getBoolPref:@"reels_show_scrubber"]) {
        userMinSec = 0;
        userDuration = 0;
        userShortScrubberEnabled = true;
    }

    return %orig(set, userTapPauseEnabled, controls, previewThumbEnabled, userMinSec, seekSec, tapSec, userDuration, userShortScrubberEnabled);
}
%end

static BOOL sciReelRefreshBypassing = NO;

%hook IGSundialFeedViewController
- (void)_refreshReelsWithParamsForNetworkRequest:(NSInteger)arg1 userDidPullToRefresh:(BOOL)arg2 {
    if ([SCIUtils getBoolPref:@"prevent_doom_scrolling"]) {
        IGRefreshControl *rc = MSHookIvar<IGRefreshControl *>(self, "_refreshControl");
        [self refreshControlDidEndFinishLoadingAnimation:rc];
        return;
    }

    if (![(UIViewController *)self isViewLoaded] || sciReelRefreshBypassing || ![SCIUtils getBoolPref:@"refresh_reel_confirm"]) {
        %orig(arg1, arg2);
        return;
    }

    // Reset the refresh control state so pull-to-refresh can trigger again
    IGRefreshControl *rc = MSHookIvar<IGRefreshControl *>(self, "_refreshControl");
    Ivar stateIvar = class_getInstanceVariable([rc class], "_refreshState");
    if (stateIvar) {
        ptrdiff_t off = ivar_getOffset(stateIvar);
        *(NSInteger *)((char *)(__bridge void *)rc + off) = 0;
    }
    if ([rc respondsToSelector:@selector(endRefreshing)])
        ((void(*)(id,SEL))objc_msgSend)(rc, @selector(endRefreshing));
    [self refreshControlDidEndFinishLoadingAnimation:rc];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Refresh Reels?"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak id weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Refresh" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        sciReelRefreshBypassing = YES;
        SEL rSel = @selector(_refreshReelsWithParamsForNetworkRequest:userDidPullToRefresh:);
        ((void(*)(id,SEL,NSInteger,BOOL))objc_msgSend)(weakSelf, rSel, arg1, arg2);
        sciReelRefreshBypassing = NO;
    }]];

    UIViewController *presenter = (UIViewController *)self;
    [presenter presentViewController:alert animated:YES completion:nil];
}
%end

// * Disable auto-unmuting reels
// Blocks all paths that can unmute: hardware buttons, headphones,
// mute switch, and the audio state announcer.
%hook IGAudioStatusAnnouncer
- (void)_didPressVolumeButton:(id)button {
    if (![SCIUtils getBoolPref:@"disable_auto_unmuting_reels"]) {
        %orig(button);
    }
}
- (void)_didUnplugHeadphones:(id)headphones {
    if (![SCIUtils getBoolPref:@"disable_auto_unmuting_reels"]) {
        %orig(headphones);
    }
}
- (void)_muteSwitchStateChanged:(id)changed {
    extern BOOL sciStoryAudioBypass;
    if (sciStoryAudioBypass || ![SCIUtils getBoolPref:@"disable_auto_unmuting_reels"]) {
        %orig(changed);
    }
}
// Block the announcer from broadcasting "audio enabled" state changes
- (void)_announceForDeviceStateChangesIfNeededForAudioEnabled:(BOOL)enabled reason:(NSInteger)reason {
    extern BOOL sciStoryAudioBypass;
    BOOL pausePlayMode = [[SCIUtils getStringPref:@"reels_tap_control"] isEqualToString:@"pause"];
    if ([SCIUtils getBoolPref:@"disable_auto_unmuting_reels"] && enabled && !pausePlayMode && !sciStoryAudioBypass) {
        return;
    }
    %orig;
}
%end