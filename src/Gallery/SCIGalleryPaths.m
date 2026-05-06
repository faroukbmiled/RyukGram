#import "SCIGalleryPaths.h"

static NSString *_galleryDirectory;
static NSString *_galleryMediaDirectory;
static NSString *_galleryThumbnailsDirectory;

@implementation SCIGalleryPaths

+ (NSString *)galleryDirectory {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        _galleryDirectory = [docs stringByAppendingPathComponent:@"Gallery"];
        [self ensureDirectoryExists:_galleryDirectory];
    });
    return _galleryDirectory;
}

+ (NSString *)galleryMediaDirectory {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _galleryMediaDirectory = [[self galleryDirectory] stringByAppendingPathComponent:@"Files"];
        [self ensureDirectoryExists:_galleryMediaDirectory];
    });
    return _galleryMediaDirectory;
}

+ (NSString *)galleryThumbnailsDirectory {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _galleryThumbnailsDirectory = [[self galleryDirectory] stringByAppendingPathComponent:@"Thumbnails"];
        [self ensureDirectoryExists:_galleryThumbnailsDirectory];
    });
    return _galleryThumbnailsDirectory;
}

+ (void)ensureDirectoryExists:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        NSError *error;
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"[SCInsta Gallery] Failed to create directory %@: %@", path, error);
        }
    }
}

@end
