#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Optional context when saving to the gallery (e.g. from the action button).
/// `source` uses the same values as `SCIGallerySource` in SCIGalleryFile.
@interface SCIGallerySaveMetadata : NSObject

@property (nonatomic, copy, nullable) NSString *sourceUsername;
@property (nonatomic, copy, nullable) NSString *sourceUserPK;
@property (nonatomic, copy, nullable) NSString *sourceProfileURLString;
@property (nonatomic, copy, nullable) NSString *sourceMediaPK;
@property (nonatomic, copy, nullable) NSString *sourceMediaCode;
@property (nonatomic, copy, nullable) NSString *sourceMediaURLString;
@property (nonatomic, assign) int16_t source;

/// If > 0, overrides probed dimensions from the file.
@property (nonatomic, assign) int32_t pixelWidth;
@property (nonatomic, assign) int32_t pixelHeight;

/// If > 0 for video, overrides probed duration (seconds).
@property (nonatomic, assign) double durationSeconds;

/// When YES, the save bypasses the recent-PK dedup guard. Bulk paths set this
/// because every carousel child shares the parent's media PK and would
/// otherwise collapse into a single gallery entry.
@property (nonatomic, assign) BOOL skipDedup;

@end

NS_ASSUME_NONNULL_END
