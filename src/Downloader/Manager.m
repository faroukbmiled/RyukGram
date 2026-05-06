#import "Manager.h"
#import "../ActionButton/SCIMediaActions.h"

@implementation SCIDownloadManager

- (instancetype)initWithDelegate:(id<SCIDownloadDelegateProtocol>)downloadDelegate {
    self = [super init];
    
    if (self) {
        self.delegate = downloadDelegate;
    }

    return self;
}

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension {
    // Properties
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    self.task = [self.session downloadTaskWithURL:url];
    
    // Default to jpg if no other reasonable length extension is provided
    self.fileExtension = [fileExtension length] >= 3 ? fileExtension : @"jpg";

    [self.task resume];
    [self.delegate downloadDidStart];
}

- (void)cancelDownload {
    [self.task cancel];
    [self.delegate downloadDidCancel];
}

// URLSession methods
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;

    [self.delegate downloadDidProgress:progress];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSURL *finalLocation = [self moveFileToCacheDir:location];
    [self.delegate downloadDidFinishWithFileURL:finalLocation];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) NSLog(@"[RyukGram] Download error: %@", error);
    [self.delegate downloadDidFinishWithError:error];
}

- (NSURL *)moveFileToCacheDir:(NSURL *)oldPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectoryPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *stem = [SCIMediaActions currentFilenameStem] ?: NSUUID.UUID.UUIDString;
    NSString *ext = self.fileExtension.length ? self.fileExtension : @"bin";

    // Disambiguate when the same stem is reused (e.g. retap on the same media)
    // so the move doesn't fail with NSCocoaError 516.
    NSURL *newPath = [[NSURL fileURLWithPath:cacheDirectoryPath]
                       URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", stem, ext]];
    NSInteger n = 1;
    while ([fileManager fileExistsAtPath:newPath.path] && n < 1000) {
        newPath = [[NSURL fileURLWithPath:cacheDirectoryPath]
                    URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%ld.%@", stem, (long)n, ext]];
        n++;
    }

    NSError *fileMoveError;
    [fileManager moveItemAtURL:oldPath toURL:newPath error:&fileMoveError];
    if (fileMoveError) {
        NSLog(@"[RyukGram] move %@ -> %@ failed: %@", oldPath.absoluteString, newPath.absoluteString, fileMoveError);
    }
    return newPath;
}

@end