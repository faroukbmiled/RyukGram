#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

@interface QuickLookDelegate : NSObject <QLPreviewControllerDataSource, QLPreviewControllerDelegate>

@property (nonatomic, strong) NSArray<NSURL *> *previewItemURLs;

- (instancetype)initWithPreviewItemURLs:(NSArray<NSURL *> *)urls;

@end