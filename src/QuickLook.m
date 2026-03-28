#import "QuickLook.h"

@implementation QuickLookDelegate

- (instancetype)initWithPreviewItemURLs:(NSArray<NSURL *> *)urls {
    self = [super init];
    if (self) {
        _previewItemURLs = [urls copy];
    }
    return self;
}

/* * QLPreviewControllerDataSource Protocol * */

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.previewItemURLs.count;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return self.previewItemURLs[index];
}

/* QLPreviewControllerDelegate Protocol */

// - (void)previewControllerWillDismiss:(QLPreviewController *)controller {}

// - (void)previewControllerDidDismiss:(QLPreviewController *)controller {}

@end