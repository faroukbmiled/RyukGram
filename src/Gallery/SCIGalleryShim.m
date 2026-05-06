#import "SCIGalleryShim.h"
#import "../Utils.h"

NSString *const kSCIFeedbackActionGalleryDeleteFile     = @"gallery_delete_file";
NSString *const kSCIFeedbackActionGalleryDeleteSelected = @"gallery_delete_selected";
NSString *const kSCIFeedbackActionGalleryBulkDelete     = @"gallery_bulk_delete";
NSString *const kSCIFeedbackActionGalleryOpenOriginal   = @"gallery_open_original";
NSString *const kSCIFeedbackActionGalleryOpenProfile    = @"gallery_open_profile";

@implementation SCIUtils (SCIGalleryShim)

+ (void)showToastForActionIdentifier:(NSString *)actionIdentifier
                            duration:(NSTimeInterval)duration
                               title:(NSString *)title
                            subtitle:(NSString *)subtitle
                        iconResource:(NSString *)iconResource {
    [SCIUtils showToastForDuration:duration title:title ?: @"" subtitle:subtitle ?: @""];
}

+ (void)showToastForActionIdentifier:(NSString *)actionIdentifier
                            duration:(NSTimeInterval)duration
                               title:(NSString *)title
                            subtitle:(NSString *)subtitle
                        iconResource:(NSString *)iconResource
                                tone:(SCIFeedbackPillTone)tone {
    [SCIUtils showToastForDuration:duration title:title ?: @"" subtitle:subtitle ?: @""];
}

@end
