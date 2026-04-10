// Story audio mute/unmute toggle. Posts mute-switch-state-changed to toggle
// IG's audio. Reads _audioEnabled on IGAudioStatusAnnouncer for icon state.

#import <AVFoundation/AVFoundation.h>
#import "StoryHelpers.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

extern "C" __weak UIViewController *sciActiveStoryViewerVC;
extern "C" void sciRefreshAllVisibleOverlays(UIViewController *);

static id sciAudioAnnouncer = nil;

static BOOL sciIGAudioEnabled(void) {
    if (!sciAudioAnnouncer) return NO;
    Ivar ivar = class_getInstanceVariable([sciAudioAnnouncer class], "_audioEnabled");
    if (!ivar) return NO;
    ptrdiff_t offset = ivar_getOffset(ivar);
    return *(BOOL *)((char *)(__bridge void *)sciAudioAnnouncer + offset);
}

// ============ Volume KVO ============

@interface _SciVolumeObserver : NSObject
@end
@implementation _SciVolumeObserver
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sciActiveStoryViewerVC) sciRefreshAllVisibleOverlays(sciActiveStoryViewerVC);
    });
}
@end
static _SciVolumeObserver *sciVolumeObserver = nil;

// ============ Public API ============

extern "C" {

BOOL sciStoryAudioBypass = NO;

void sciToggleStoryAudio(void) {
    BOOL on = sciIGAudioEnabled();
    sciStoryAudioBypass = YES;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"mute-switch-state-changed"
                      object:nil
                    userInfo:@{@"mute-state": @(on ? 0 : 1)}];
    sciStoryAudioBypass = NO;
    if (sciActiveStoryViewerVC) sciRefreshAllVisibleOverlays(sciActiveStoryViewerVC);
}

BOOL sciIsStoryAudioEnabled(void) {
    return sciIGAudioEnabled();
}

static BOOL sciKVORegistered = NO;

void sciInitStoryAudioState(void) {
    if (sciKVORegistered) return;
    if (!sciVolumeObserver) sciVolumeObserver = [_SciVolumeObserver new];
    @try {
        [[AVAudioSession sharedInstance] addObserver:sciVolumeObserver
                                         forKeyPath:@"outputVolume"
                                            options:NSKeyValueObservingOptionNew
                                            context:NULL];
        sciKVORegistered = YES;
    } @catch (__unused id e) {}
}

void sciResetStoryAudioState(void) {
    if (!sciKVORegistered) return;
    @try {
        [[AVAudioSession sharedInstance] removeObserver:sciVolumeObserver forKeyPath:@"outputVolume"];
        sciKVORegistered = NO;
    } @catch (__unused id e) {}
}

} // extern "C"

// ============ Announcer hooks ============

static id (*orig_announcerInit)(id, SEL);
static id new_announcerInit(id self, SEL _cmd) {
    id r = orig_announcerInit(self, _cmd);
    sciAudioAnnouncer = self;
    return r;
}

static void (*orig_announce)(id, SEL, BOOL, NSInteger);
static void new_announce(id self, SEL _cmd, BOOL enabled, NSInteger reason) {
    orig_announce(self, _cmd, enabled, reason);
    if (sciActiveStoryViewerVC) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sciActiveStoryViewerVC) sciRefreshAllVisibleOverlays(sciActiveStoryViewerVC);
        });
    }
}

// ============ 3-dot menu item ============

extern "C" NSArray *sciMaybeAppendStoryAudioMenuItem(NSArray *items) {
    if (!sciActiveStoryViewerVC) return items;

    BOOL looksLikeStoryHeader = NO;
    for (id it in items) {
        @try {
            NSString *t = [NSString stringWithFormat:@"%@", [it valueForKey:@"title"] ?: @""];
            if ([t isEqualToString:@"Report"] || [t isEqualToString:@"Mute"] ||
                [t isEqualToString:@"Unfollow"] || [t isEqualToString:@"Follow"] ||
                [t isEqualToString:@"Hide"]) { looksLikeStoryHeader = YES; break; }
        } @catch (__unused id e) {}
    }
    if (!looksLikeStoryHeader) return items;

    Class menuItemCls = NSClassFromString(@"IGDSMenuItem");
    if (!menuItemCls) return items;

    BOOL on = sciIGAudioEnabled();
    NSString *title = on ? @"Mute story audio" : @"Unmute story audio";
    void (^handler)(void) = ^{ sciToggleStoryAudio(); };

    id newItem = nil;
    @try {
        typedef id (*Init)(id, SEL, id, id, id);
        newItem = ((Init)objc_msgSend)([menuItemCls alloc],
            @selector(initWithTitle:image:handler:), title, nil, handler);
    } @catch (__unused id e) {}

    if (!newItem) return items;
    NSMutableArray *newItems = [items mutableCopy];
    [newItems addObject:newItem];
    return [newItems copy];
}

// ============ Ringer listener ============

static void sciRingerChanged(CFNotificationCenterRef center, void *observer,
                              CFNotificationName name, const void *object,
                              CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sciActiveStoryViewerVC) sciRefreshAllVisibleOverlays(sciActiveStoryViewerVC);
    });
}

// ============ Init ============

__attribute__((constructor)) static void _storyAudioInit(void) {
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        sciRingerChanged, CFSTR("com.apple.springboard.ringerstate"),
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    Class cls = NSClassFromString(@"IGAudioStatusAnnouncer");
    if (!cls) return;
    MSHookMessageEx(cls, @selector(init), (IMP)new_announcerInit, (IMP *)&orig_announcerInit);
    SEL s = NSSelectorFromString(@"_announceForDeviceStateChangesIfNeededForAudioEnabled:reason:");
    if (class_getInstanceMethod(cls, s))
        MSHookMessageEx(cls, s, (IMP)new_announce, (IMP *)&orig_announce);
}
