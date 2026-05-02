// View highlight cover — opens the cover image in the full-screen media viewer.

#import "../../Utils.h"
#import "../../Downloader/Download.h"
#import "../../ActionButton/SCIMediaViewer.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

// Find the IGStoryTrayCell whose long-press is currently active.
static UIView *sciFindLongPressedCell(UIView *root) {
    Class cellCls = NSClassFromString(@"IGStoryTrayCell");
    if (!cellCls) return nil;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count) {
        UIView *v = stack.lastObject; [stack removeLastObject];
        if ([v isKindOfClass:cellCls]) {
            for (UIGestureRecognizer *gr in v.gestureRecognizers) {
                if ([gr isKindOfClass:[UILongPressGestureRecognizer class]] &&
                    (gr.state == UIGestureRecognizerStateBegan || gr.state == UIGestureRecognizerStateChanged))
                    return v;
            }
        }
        for (UIView *sub in v.subviews) [stack addObject:sub];
    }
    return nil;
}

// Walk the cell's view tree for the first non-trivial UIImage. Used as a fallback
// when the IGImageURL chain is missing or the network fetch fails.
static UIImage *sciCoverImageFromCell(UIView *cell) {
    if (!cell) return nil;
    Class igImageView = NSClassFromString(@"IGImageView") ?: [UIImageView class];
    NSMutableArray *stack = [NSMutableArray arrayWithObject:cell];
    while (stack.count) {
        UIView *v = stack.lastObject; [stack removeLastObject];
        if ([v isKindOfClass:igImageView] && [v isKindOfClass:[UIImageView class]]) {
            UIImage *img = [(UIImageView *)v image];
            if (img && img.size.width > 10) return img;
        }
        for (UIView *sub in v.subviews) [stack addObject:sub];
    }
    return nil;
}

static void sciViewCoverImage(UIImage *image) {
    if (!image) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"Could not find cover image")];
        return;
    }
    NSData *data = UIImageJPEGRepresentation(image, 1.0);
    if (!data) return;
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"cover_%@.jpg", [[NSUUID UUID] UUIDString]]];
    [data writeToFile:tmpPath atomically:YES];
    [SCIMediaViewer showWithVideoURL:nil photoURL:[NSURL fileURLWithPath:tmpPath] caption:nil];
}

// Captured at action-sheet presentation time so the handler can read the cell after
// the long-press has ended.
static __weak UIView *sciLongPressedHighlightCell = nil;

// Read a named ivar (walking superclasses) without messaging the object — safe on
// proxy classes that crash under isKindOfClass:/class.
static id sciReadIvarSafe(id obj, const char *name) {
    if (!obj || !name) return nil;
    Class c = object_getClass(obj);
    Ivar iv = nil;
    while (c && !iv) {
        iv = class_getInstanceVariable(c, name);
        if (!iv) c = class_getSuperclass(c);
    }
    if (!iv) return nil;
    id v = nil;
    @try { v = object_getIvar(obj, iv); } @catch (__unused id e) {}
    return v;
}

// Manual isKindOfClass — avoids messaging proxies / NSMessageBuilder.
static BOOL sciIsNSURL(id obj) {
    if (!obj) return NO;
    Class c = object_getClass(obj);
    Class target = [NSURL class];
    while (c) { if (c == target) return YES; c = class_getSuperclass(c); }
    return NO;
}

// IGStoryTrayCell._avatarView._ownerImageView._imageView._imageSpecifier
//                                            ._remoteImage_imageURL._url
// The CDN signs the full query string, so the URL must be used verbatim — stripping
// stp= produces a 22-byte signature error.
static NSURL *sciHighResCoverURLFromCell(UIView *cell) {
    id chain = cell;
    static const char * const path[] = {
        "_avatarView", "_ownerImageView", "_imageView",
        "_imageSpecifier", "_remoteImage_imageURL", "_url", NULL
    };
    for (const char * const *seg = path; *seg && chain; seg++) chain = sciReadIvarSafe(chain, *seg);
    return sciIsNSURL(chain) ? (NSURL *)chain : nil;
}

static void sciFetchAndPresentCover(NSURL *url, UIView *fallbackCell) {
    if (!url) {
        sciViewCoverImage(sciCoverImageFromCell(fallbackCell));
        return;
    }
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!data || err || data.length < 512) {
                    sciViewCoverImage(sciCoverImageFromCell(fallbackCell));
                    return;
                }
                NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"cover_%@.jpg", [[NSUUID UUID] UUIDString]]];
                [data writeToFile:tmpPath atomically:YES];
                [SCIMediaViewer showWithVideoURL:nil photoURL:[NSURL fileURLWithPath:tmpPath] caption:nil];
            });
        }];
    [task resume];
}

static void (*orig_present)(id, SEL, id, BOOL, id);
static void new_present(id self, SEL _cmd, id vc, BOOL animated, id completion) {
    if ([SCIUtils getBoolPref:@"download_highlight_cover"] &&
        [NSStringFromClass([vc class]) containsString:@"ActionSheet"] &&
        [NSStringFromClass([self class]) containsString:@"Profile"]) {

        UIView *cell = sciFindLongPressedCell([(UIViewController *)self view]);
        sciLongPressedHighlightCell = cell;

        if (cell) {
            Ivar actIvar = class_getInstanceVariable([vc class], "_actions");
            NSArray *actions = actIvar ? object_getIvar(vc, actIvar) : nil;
            if (actions && actions.count >= 2 && actions.count <= 6) {
                Class actionCls = NSClassFromString(@"IGActionSheetControllerAction");
                if (actionCls) {
                    void (^handler)(void) = ^{
                        NSURL *hi = sciHighResCoverURLFromCell(sciLongPressedHighlightCell);
                        sciFetchAndPresentCover(hi, sciLongPressedHighlightCell);
                    };

                    SEL initSel = @selector(initWithTitle:subtitle:style:handler:accessibilityIdentifier:accessibilityLabel:);
                    typedef id (*InitFn)(id, SEL, id, id, NSInteger, id, id, id);
                    id newAction = ((InitFn)objc_msgSend)([actionCls alloc], initSel,
                        SCILocalized(@"View cover"), nil, 0, handler, nil, nil);

                    if (newAction) {
                        NSMutableArray *newActions = [actions mutableCopy];
                        [newActions addObject:newAction];
                        object_setIvar(vc, actIvar, [newActions copy]);
                    }
                }
            }
        }
    }

    orig_present(self, _cmd, vc, animated, completion);
}

__attribute__((constructor)) static void _highlightInit(void) {
    MSHookMessageEx([UIViewController class], @selector(presentViewController:animated:completion:),
                    (IMP)new_present, (IMP *)&orig_present);
}
