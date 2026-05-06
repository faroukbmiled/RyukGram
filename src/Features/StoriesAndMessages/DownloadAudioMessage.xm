// Download voice messages from DMs. Detects audio messages via the
// menuConfiguration hook, then injects a Download item into the long-press
// PrismMenu. Routes through SCIDownloadMenu (Photos / Gallery / Share).

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Downloader/Download.h"
#import "../../UI/SCIDownloadMenu.h"
#import "../../Gallery/SCIGalleryFile.h"
#import "../../Gallery/SCIGallerySaveMetadata.h"
#import "../../ActionButton/SCIMediaActions.h"
#import "OverlayHelpers.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <AVFoundation/AVFoundation.h>

typedef id (*SCIMsgSendId)(id, SEL);
static inline id sciDAF(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    return ((SCIMsgSendId)objc_msgSend)(obj, sel);
}

static BOOL sciAudioMenuPending = NO;
static id sciLastAudioViewModel = nil;

// Demangled: IGDirectMessageMenuConfiguration.IGDirectMessageMenuConfiguration
%hook _TtC32IGDirectMessageMenuConfiguration32IGDirectMessageMenuConfiguration

+ (id)menuConfigurationWithEligibleOptions:(id)options
                          messageViewModel:(id)arg2
                               contentType:(id)arg3
                                 isSticker:(_Bool)arg4
                            isMusicSticker:(_Bool)arg5
                          directNuxManager:(id)arg6
                       sessionUserDefaults:(id)arg7
                               launcherSet:(id)arg8
                               userSession:(id)arg9
                                tapHandler:(id)arg10
{
    if ([SCIUtils getBoolPref:@"download_audio_message"] &&
        [arg3 isKindOfClass:[NSString class]] && [arg3 isEqualToString:@"voice_media"]) {
        sciAudioMenuPending = YES;
        sciLastAudioViewModel = arg2;
    }
    return %orig;
}

%end

// PrismMenu uses Swift classes with mangled names — hooked from %ctor.
static id (*orig_prismMenuView_init3)(id, SEL, NSArray *, id, BOOL);

static id new_prismMenuView_init3(id self, SEL _cmd, NSArray *elements, id header, BOOL edr) {
    if (!sciAudioMenuPending) return orig_prismMenuView_init3(self, _cmd, elements, header, edr);
    sciAudioMenuPending = NO;

    if (![SCIUtils getBoolPref:@"download_audio_message"])
        return orig_prismMenuView_init3(self, _cmd, elements, header, edr);

    Class builderClass = NSClassFromString(@"IGDSPrismMenuItemBuilder");
    Class elementClass = NSClassFromString(@"IGDSPrismMenuElement");
    if (!builderClass || !elementClass || elements.count == 0)
        return orig_prismMenuView_init3(self, _cmd, elements, header, edr);

    typedef id (*InitFn)(id, SEL, id);
    typedef id (*WithFn)(id, SEL, id);
    typedef id (*BuildFn)(id, SEL);

    id capturedVM = sciLastAudioViewModel;
    void (^handler)(void) = ^{
        if (!capturedVM) return;

        // vm -> audio (IGDirectAudio) -> _server_audio (IGAudio) -> playbackURL
        id directAudio = nil;
        @try { directAudio = [capturedVM valueForKey:@"audio"]; } @catch (NSException *e) {}
        if (!directAudio) {
            [SCIUtils showErrorHUDWithDescription:SCILocalized(@"Could not get audio data. Try again after refreshing the chat.")];
            return;
        }

        Ivar serverAudioIvar = class_getInstanceVariable([directAudio class], "_server_audio");
        id serverAudio = serverAudioIvar ? object_getIvar(directAudio, serverAudioIvar) : nil;
        if (!serverAudio) {
            [SCIUtils showErrorHUDWithDescription:SCILocalized(@"Audio not loaded yet. Play the message first and try again.")];
            return;
        }

        NSURL *playbackURL = sciDAF(serverAudio, @selector(playbackURL));
        if (!playbackURL) playbackURL = sciDAF(serverAudio, @selector(fallbackURL));
        if (!playbackURL) {
            [SCIUtils showErrorHUDWithDescription:SCILocalized(@"No audio URL found. Try again after refreshing the chat.")];
            return;
        }

        SCIGallerySaveMetadata *md = sciDMMetadataFromMessage(capturedVM);
        @try {
            id mediaId = sciDAF(serverAudio, @selector(mediaId));
            if ([mediaId respondsToSelector:@selector(stringValue)]) md.sourceMediaPK = [mediaId stringValue];
            else if ([mediaId isKindOfClass:[NSString class]]) md.sourceMediaPK = mediaId;
        } @catch (__unused id e) {}

        // Server can return Ogg/Opus — keep the source extension when it's a
        // known audio container, default m4a otherwise.
        NSString *urlExt = [[playbackURL.path pathExtension] lowercaseString];
        if (!SCIGalleryExtensionIsAudio(urlExt)) urlExt = @"m4a";

        [SCIMediaActions setCurrentFilenameStem:
            [SCIMediaActions filenameStemForUsername:md.sourceUsername contextLabel:@"voice"]];

        [SCIDownloadMenu presentForURL:playbackURL
                                  mode:SCIDownloadMenuModeRemoteURL
                         fileExtension:urlExt
                              hudLabel:SCILocalized(@"Download audio")
                              metadata:md
                               isAudio:YES
                                fromVC:nil];
    };

    id builder = ((InitFn)objc_msgSend)([builderClass alloc], @selector(initWithTitle:), SCILocalized(@"Download"));
    builder = ((WithFn)objc_msgSend)(builder, @selector(withImage:), [UIImage systemImageNamed:@"arrow.down.circle"]);
    builder = ((WithFn)objc_msgSend)(builder, @selector(withHandler:), handler);
    id menuItem = ((BuildFn)objc_msgSend)(builder, @selector(build));
    if (!menuItem) return orig_prismMenuView_init3(self, _cmd, elements, header, edr);

    // Wrap in IGDSPrismMenuElement: clone _subtype from a sibling, attach the item.
    id templateEl = elements[0];
    id newElement = [[templateEl class] new];
    Ivar subtypeIvar = class_getInstanceVariable([templateEl class], "_subtype");
    Ivar itemIvar = class_getInstanceVariable([templateEl class], "_item_menuItem");
    if (!newElement || !subtypeIvar || !itemIvar)
        return orig_prismMenuView_init3(self, _cmd, elements, header, edr);

    ptrdiff_t offset = ivar_getOffset(subtypeIvar);
    *(uint64_t *)((uint8_t *)(__bridge void *)newElement + offset) =
        *(uint64_t *)((uint8_t *)(__bridge void *)templateEl + offset);
    object_setIvar(newElement, itemIvar, menuItem);

    NSMutableArray *newElements = [NSMutableArray arrayWithObject:newElement];
    [newElements addObjectsFromArray:elements];
    return orig_prismMenuView_init3(self, _cmd, newElements, header, edr);
}

%ctor {
    Class prismMenuView = objc_getClass("IGDSPrismMenu.IGDSPrismMenuView");
    if (prismMenuView) {
        SEL sel = @selector(initWithMenuElements:headerText:edrEnabled:);
        if ([prismMenuView instancesRespondToSelector:sel])
            MSHookMessageEx(prismMenuView, sel, (IMP)new_prismMenuView_init3, (IMP *)&orig_prismMenuView_init3);
    }
}
