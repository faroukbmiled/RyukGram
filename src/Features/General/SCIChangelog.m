#import "SCIChangelog.h"
#import "../../Utils.h"
#import "../../Tweak.h"

#define kRepo SCIRepoSlug
// Stores the SCIVersionString of the last tweak build whose popup was shown.
// When the tweak updates, this mismatches and triggers a fresh check.
static NSString *const kLastSeenVersionKey = @"sci_changelog_last_seen_version";
// Debug pref: when YES, the popup fires every launch regardless of version.
static NSString *const kForceShowKey = @"sci_changelog_force_show";

// MARK: - Cache

static NSString *sciChangelogCacheDir(void) {
    static NSString *dir = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *base = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        dir = [base stringByAppendingPathComponent:@"RyukGramChangelog"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

static NSString *sciCachedReleasePath(NSString *tag) {
    NSString *safe = [tag stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [sciChangelogCacheDir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", safe]];
}

static NSDictionary *sciLoadCachedRelease(NSString *tag) {
    NSData *data = [NSData dataWithContentsOfFile:sciCachedReleasePath(tag)];
    if (!data) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

static void sciSaveCachedRelease(NSString *tag, NSDictionary *json) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    if (data) [data writeToFile:sciCachedReleasePath(tag) atomically:YES];
}

// MARK: - Network

static void sciFetchJSON(NSString *url, void (^completion)(NSDictionary *)) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]] || !json[@"tag_name"]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(json); });
    }] resume];
}

// Fetch a specific tag, falling back to /releases/latest on 404 so the popup
// works in the window between a local version bump and the release being
// published on GitHub.
static void sciFetchRelease(NSString *tag, void (^completion)(NSDictionary *)) {
    NSString *tagURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/releases/tags/%@", kRepo, tag];
    sciFetchJSON(tagURL, ^(NSDictionary *json) {
        if (json) {
            sciSaveCachedRelease(json[@"tag_name"], json);
            completion(json);
            return;
        }
        NSString *latestURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/releases/latest", kRepo];
        sciFetchJSON(latestURL, ^(NSDictionary *latest) {
            if (latest) sciSaveCachedRelease(latest[@"tag_name"], latest);
            completion(latest);
        });
    });
}

static void sciFetchReleaseList(void (^completion)(NSArray<NSDictionary *> *)) {
    NSString *url = [NSString stringWithFormat:@"https://api.github.com/repos/%@/releases?per_page=50", kRepo];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSArray *arr = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([arr isKindOfClass:[NSArray class]] ? arr : nil);
        });
    }] resume];
}

// MARK: - Markdown renderer

static NSAttributedString *sciRenderMarkdown(NSString *md) {
    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] init];
    if (!md.length) return out;

    UIFont *body = [UIFont systemFontOfSize:15];
    UIFont *h2   = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    UIFont *h3   = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    UIColor *fg  = [UIColor labelColor];
    UIColor *muted = [UIColor secondaryLabelColor];

    NSMutableParagraphStyle *bodyPS = [NSMutableParagraphStyle new];
    bodyPS.lineSpacing = 2;
    bodyPS.paragraphSpacing = 3;

    NSMutableParagraphStyle *headingPS = [NSMutableParagraphStyle new];
    headingPS.lineSpacing = 2;
    headingPS.paragraphSpacing = 4;
    headingPS.paragraphSpacingBefore = 10;

    NSArray<NSString *> *lines = [md componentsSeparatedByString:@"\n"];
    BOOL firstEmitted = NO;
    for (NSString *raw in lines) {
        // Skip blank lines — paragraph spacing already handles breathing room.
        if (raw.length == 0) continue;

        NSString *line = raw;
        NSMutableDictionary *attrs = [@{
            NSFontAttributeName: body,
            NSForegroundColorAttributeName: fg,
            NSParagraphStyleAttributeName: bodyPS,
        } mutableCopy];
        NSString *prefix = nil;

        if ([line hasPrefix:@"## "]) {
            attrs[NSFontAttributeName] = h2;
            attrs[NSParagraphStyleAttributeName] = firstEmitted ? headingPS : bodyPS;
            line = [line substringFromIndex:3];
        } else if ([line hasPrefix:@"### "]) {
            attrs[NSFontAttributeName] = h3;
            attrs[NSParagraphStyleAttributeName] = firstEmitted ? headingPS : bodyPS;
            line = [line substringFromIndex:4];
        } else if ([line hasPrefix:@"- "] || [line hasPrefix:@"* "]) {
            prefix = @"  •  ";
            line = [line substringFromIndex:2];
        } else if ([line hasPrefix:@"> "]) {
            attrs[NSForegroundColorAttributeName] = muted;
            line = [line substringFromIndex:2];
        }

        if (firstEmitted) {
            [out appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:attrs]];
        }
        if (prefix) {
            [out appendAttributedString:[[NSAttributedString alloc] initWithString:prefix attributes:attrs]];
        }

        NSMutableAttributedString *seg = [[NSMutableAttributedString alloc] initWithString:line attributes:attrs];

        // Inline **bold**
        NSRegularExpression *boldRx = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.+?)\\*\\*" options:0 error:nil];
        NSArray *boldMatches = [boldRx matchesInString:seg.string options:0 range:NSMakeRange(0, seg.string.length)];
        for (NSTextCheckingResult *m in [boldMatches reverseObjectEnumerator]) {
            NSString *inner = [seg.string substringWithRange:[m rangeAtIndex:1]];
            UIFont *baseFont = attrs[NSFontAttributeName];
            UIFont *boldFont = [UIFont systemFontOfSize:baseFont.pointSize weight:UIFontWeightBold];
            NSMutableDictionary *boldAttrs = [attrs mutableCopy];
            boldAttrs[NSFontAttributeName] = boldFont;
            NSAttributedString *replacement = [[NSAttributedString alloc] initWithString:inner attributes:boldAttrs];
            [seg replaceCharactersInRange:m.range withAttributedString:replacement];
        }

        // Inline [text](url) links
        NSRegularExpression *linkRx = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\(([^)]+)\\)" options:0 error:nil];
        NSArray *linkMatches = [linkRx matchesInString:seg.string options:0 range:NSMakeRange(0, seg.string.length)];
        for (NSTextCheckingResult *m in [linkMatches reverseObjectEnumerator]) {
            NSString *text = [seg.string substringWithRange:[m rangeAtIndex:1]];
            NSString *url = [seg.string substringWithRange:[m rangeAtIndex:2]];
            NSMutableDictionary *linkAttrs = [attrs mutableCopy];
            linkAttrs[NSLinkAttributeName] = url;
            NSAttributedString *replacement = [[NSAttributedString alloc] initWithString:text attributes:linkAttrs];
            [seg replaceCharactersInRange:m.range withAttributedString:replacement];
        }

        [out appendAttributedString:seg];
        firstEmitted = YES;
    }

    return out;
}

// MARK: - Detail view controller (renders one release)

@interface _SCIChangelogDetailVC : UIViewController
@property (nonatomic, copy) NSDictionary *releaseJSON;
@property (nonatomic, copy) void (^onDismiss)(void);
@end

@implementation _SCIChangelogDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    NSString *name = self.releaseJSON[@"name"] ?: self.releaseJSON[@"tag_name"] ?: @"?";
    NSString *body = self.releaseJSON[@"body"] ?: @"";
    NSString *htmlURL = self.releaseJSON[@"html_url"] ?: @"";
    self.title = SCILocalized(@"What's new in RyukGram");

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                       target:self
                                                       action:@selector(done)];

    // Tap the release-name heading to open the GitHub page.
    NSString *header = htmlURL.length
        ? [NSString stringWithFormat:@"## [%@](%@)\n", name, htmlURL]
        : [NSString stringWithFormat:@"## %@\n", name];
    NSAttributedString *attrBody = sciRenderMarkdown([header stringByAppendingString:body]);

    UITextView *tv = [UITextView new];
    tv.editable = NO;
    tv.backgroundColor = [UIColor clearColor];
    tv.textContainerInset = UIEdgeInsetsMake(16, 16, 24, 16);
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.attributedText = attrBody;
    tv.alwaysBounceVertical = YES;
    [self.view addSubview:tv];

    [NSLayoutConstraint activateConstraints:@[
        [tv.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// MARK: - Releases list view controller

@interface _SCIReleaseListVC : UITableViewController
@property (nonatomic, copy) NSArray<NSDictionary *> *releases;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation _SCIReleaseListVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"Release notes");
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                       target:self
                                                       action:@selector(done)];
    self.tableView.rowHeight = 60;

    UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spin.hidesWhenStopped = YES;
    [spin startAnimating];
    self.tableView.backgroundView = spin;
    self.spinner = spin;

    [self loadReleases];
}

- (void)loadReleases {
    sciFetchReleaseList(^(NSArray<NSDictionary *> *arr) {
        self.releases = arr ?: @[];
        [self.spinner stopAnimating];
        self.tableView.backgroundView = nil;
        if (self.releases.count == 0) {
            UILabel *empty = [UILabel new];
            empty.text = SCILocalized(@"No releases");
            empty.textAlignment = NSTextAlignmentCenter;
            empty.textColor = [UIColor secondaryLabelColor];
            empty.font = [UIFont systemFontOfSize:15];
            self.tableView.backgroundView = empty;
        }
        [self.tableView reloadData];
    });
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return self.releases.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"r"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"r"];
    NSDictionary *rel = self.releases[ip.row];
    NSString *tag = rel[@"tag_name"];
    NSString *title = rel[@"name"] ?: tag;

    NSMutableArray<NSString *> *tags = [NSMutableArray array];
    if (ip.row == 0) [tags addObject:SCILocalized(@"latest")];
    if ([tag isEqualToString:SCIVersionString]) [tags addObject:SCILocalized(@"installed")];
    if (tags.count) {
        title = [NSString stringWithFormat:@"%@  (%@)", title, [tags componentsJoinedByString:@", "]];
    }
    cell.textLabel.text = title;
    NSString *published = rel[@"published_at"];
    cell.detailTextLabel.text = published ? [published substringToIndex:MIN((NSUInteger)10, published.length)] : @"";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *rel = self.releases[ip.row];
    _SCIChangelogDetailVC *vc = [_SCIChangelogDetailVC new];
    vc.releaseJSON = rel;
    [self.navigationController pushViewController:vc animated:YES];
}

@end

// MARK: - Public API

@implementation SCIChangelog

+ (UIViewController *)topVCInWindow:(UIWindow *)window {
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

+ (void)presentReleaseJSON:(NSDictionary *)json onDismiss:(void(^)(void))onDismiss fromWindow:(UIWindow *)window {
    _SCIChangelogDetailVC *vc = [_SCIChangelogDetailVC new];
    vc.releaseJSON = json;
    vc.onDismiss = onDismiss;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        sheet.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent,
        ];
        sheet.prefersGrabberVisible = YES;
    }
    [[self topVCInWindow:window] presentViewController:nav animated:YES completion:nil];
}

+ (void)presentIfNewFromWindow:(UIWindow *)window {
    if (!window) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL force = [ud boolForKey:kForceShowKey];

    // Fast-path: already shown for this tweak version — skip all I/O.
    if (!force && [[ud stringForKey:kLastSeenVersionKey] isEqualToString:SCIVersionString]) return;

    void (^show)(NSDictionary *) = ^(NSDictionary *json) {
        if (!json) return;
        // Mark seen on show so any dismissal path (Done, swipe) is covered.
        [[NSUserDefaults standardUserDefaults] setObject:SCIVersionString forKey:kLastSeenVersionKey];
        [self presentReleaseJSON:json onDismiss:nil fromWindow:window];
    };

    NSDictionary *cached = sciLoadCachedRelease(SCIVersionString);
    if (cached) { show(cached); return; }
    sciFetchRelease(SCIVersionString, ^(NSDictionary *json) { show(json); });
}

+ (void)presentAllFromViewController:(UIViewController *)host {
    if (!host) return;
    _SCIReleaseListVC *list = [_SCIReleaseListVC new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
        sheet.prefersGrabberVisible = YES;
    }
    [host presentViewController:nav animated:YES completion:nil];
}

@end
