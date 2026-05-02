// Let the story photo sticker picker include videos.

#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// IGStickerGalleryViewController declared in InstagramHeaders.h

%hook IGStickerGalleryViewController

- (id)initWithUserSession:(id)session
   interfaceConfiguration:(id)cfg
       preferredMediaTypes:(NSArray *)types
            rangeStartDate:(id)start
              rangeEndDate:(id)end
         cameraDestination:(NSInteger)dest
    photoStickerEntryPoint:(BOOL)entry
{
    if (entry && [SCIUtils getBoolPref:@"photo_sticker_allow_video"]) {
        types = @[@1, @2];
    }
    return %orig(session, cfg, types, start, end, dest, entry);
}

%end
