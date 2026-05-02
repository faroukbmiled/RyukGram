#import <Foundation/Foundation.h>

// * Tweak version *
extern NSString *SCIVersionString;

// * Repo URLs — single source of truth, not localized *
static NSString *const SCIRepoSlug = @"faroukbmiled/RyukGram";
static NSString *const SCIRepoURL = @"https://github.com/faroukbmiled/RyukGram";
static NSString *const SCIRepoIssuesURL = @"https://github.com/faroukbmiled/RyukGram/issues";
static NSString *const SCIRepoReleasesURL = @"https://github.com/faroukbmiled/RyukGram/releases";
static NSString *const SCIRepoTranslateURL = @"https://github.com/faroukbmiled/RyukGram#translating-ryukgram";

// Variables that work across features
extern BOOL dmVisualMsgsViewedButtonEnabled; // Whether story dm unlimited views button is enabled
extern BOOL dmSeenToggleEnabled; // Whether read receipts toggle is active