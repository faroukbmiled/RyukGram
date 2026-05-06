#import "SCIGallerySaveMetadata.h"
#import "SCIGalleryFile.h"

@implementation SCIGallerySaveMetadata

- (instancetype)init {
    if ((self = [super init])) {
        _source = (int16_t)SCIGallerySourceFeed;
    }
    return self;
}

@end
