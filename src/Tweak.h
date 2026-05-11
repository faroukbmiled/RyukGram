#import <Foundation/Foundation.h>

// * Tweak version *
extern NSString *SCIVersionString;

// * URLs — single source of truth, not localized *
static NSString *const SCIRepoSlug = @"faroukbmiled/RyukGram";
static NSString *const SCIRepoURL = @"https://github.com/faroukbmiled/RyukGram";
static NSString *const SCIRepoIssuesURL = @"https://github.com/faroukbmiled/RyukGram/issues";
static NSString *const SCIRepoReleasesURL = @"https://github.com/faroukbmiled/RyukGram/releases";
static NSString *const SCIRepoTranslateURL = @"https://github.com/faroukbmiled/RyukGram#translating-ryukgram";
static NSString *const SCIAuthorURL = @"https://github.com/faroukbmiled";
static NSString *const SCITelegramURL = @"https://t.me/ryukgram";
static NSString *const SCITelegramScheme = @"tg://resolve?domain=ryukgram";
static NSString *const SCIDonateURL = @"https://buymeacoffee.com/axryuk";
static NSString *const SCISoCuulRepoURL = @"https://github.com/SoCuul/SCInsta";
static NSString *const SCISoCuulDonateURL = @"https://ko-fi.com/SoCuul";

// Variables that work across features
extern BOOL dmVisualMsgsViewedButtonEnabled; // Whether story dm unlimited views button is enabled
extern BOOL dmSeenToggleEnabled; // Whether read receipts toggle is active