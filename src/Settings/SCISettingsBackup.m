#import "SCISettingsBackup.h"
#import "TweakSettings.h"
#import "SCISetting.h"
#import "../Utils.h"
#import "../Tweak.h"
#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>
#import "../../modules/JGProgressHUD/JGProgressHUD.h"

// Settings backup/restore: export prefs as JSON file or QR, import from file
// or photo. Import resets known prefs to defaults then applies imported ones.

#pragma mark - Preview view controller

typedef NS_ENUM(NSInteger, SCIBackupPreviewRowKind) {
    SCIBackupPreviewRowKindReadOnly,
    SCIBackupPreviewRowKindSwitch,
    SCIBackupPreviewRowKindMenu,
};

@interface SCIBackupPreviewRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy, nullable) NSString *defaultsKey;
@property (nonatomic) SCIBackupPreviewRowKind kind;
@property (nonatomic, strong, nullable) NSArray<NSDictionary *> *menuOptions;
@end
@implementation SCIBackupPreviewRow
@end

@interface SCIBackupPreviewGroup : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSMutableArray<SCIBackupPreviewRow *> *rows;
@property (nonatomic) BOOL collapsed;
@end
@implementation SCIBackupPreviewGroup
@end

@class SCIBackupPreviewVC, SCIBackupPreviewGroup;
@interface SCISettingsBackup (PreviewBuilder)
+ (NSArray<SCIBackupPreviewGroup *> *)buildPreviewGroupsForSettings:(NSDictionary *)values;
+ (void)collectOptionsFromMenu:(UIMenu *)menu defaultsKeyOut:(NSString **)outKey into:(NSMutableArray *)out;
+ (NSString *)menuTitleForBaseMenu:(UIMenu *)menu values:(NSDictionary *)values resolvedKey:(id *)outRaw;
@end

@interface SCIBackupPreviewVC : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (nonatomic, strong) NSMutableDictionary *mutableSettings;
@property (nonatomic, strong, nullable) UIImage *qrImage;
@property (nonatomic, copy) NSString *primaryActionTitle;
@property (nonatomic, copy) void (^primaryAction)(SCIBackupPreviewVC *vc);

@property (nonatomic, strong) NSArray<SCIBackupPreviewGroup *> *allGroups;
@property (nonatomic, strong) NSArray<SCIBackupPreviewGroup *> *visibleGroups;
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIBarButtonItem *editToggleItem;
@property (nonatomic) BOOL editMode;
@end

@implementation SCIBackupPreviewVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self
                                                      action:@selector(cancel)];

    NSMutableArray *rightItems = [NSMutableArray array];
    if (self.primaryActionTitle.length && self.primaryAction) {
        [rightItems addObject:[[UIBarButtonItem alloc] initWithTitle:self.primaryActionTitle
                                                                style:UIBarButtonItemStyleDone
                                                               target:self
                                                               action:@selector(runPrimary)]];
    }
    self.editToggleItem = [[UIBarButtonItem alloc] initWithTitle:@"Edit"
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(toggleEditMode)];
    [rightItems addObject:self.editToggleItem];
    self.navigationItem.rightBarButtonItems = rightItems;

    UITableView *table = [[UITableView alloc] initWithFrame:self.view.bounds
                                                       style:UITableViewStyleInsetGrouped];
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    table.dataSource = self;
    table.delegate = self;
    table.rowHeight = UITableViewAutomaticDimension;
    table.estimatedRowHeight = 50;
    table.sectionHeaderHeight = UITableViewAutomaticDimension;
    table.estimatedSectionHeaderHeight = 44;
    [self.view addSubview:table];
    self.tableView = table;

    if (self.qrImage) {
        CGFloat headerHeight = 280;
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, headerHeight)];
        UIImageView *qr = [[UIImageView alloc] init];
        qr.image = self.qrImage;
        qr.contentMode = UIViewContentModeScaleAspectFit;
        qr.layer.magnificationFilter = kCAFilterNearest;
        qr.backgroundColor = [UIColor whiteColor];
        qr.layer.cornerRadius = 12;
        qr.layer.masksToBounds = YES;
        qr.translatesAutoresizingMaskIntoConstraints = NO;
        [header addSubview:qr];
        [NSLayoutConstraint activateConstraints:@[
            [qr.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
            [qr.topAnchor constraintEqualToAnchor:header.topAnchor constant:20],
            [qr.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-20],
            [qr.widthAnchor constraintEqualToConstant:240],
            [qr.heightAnchor constraintEqualToConstant:240],
        ]];
        table.tableHeaderView = header;
    }

    UISearchController *sc = [[UISearchController alloc] initWithSearchResultsController:nil];
    sc.searchResultsUpdater = self;
    sc.obscuresBackgroundDuringPresentation = NO;
    sc.searchBar.placeholder = @"Search settings";
    self.navigationItem.searchController = sc;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.searchController = sc;

    self.allGroups = [SCISettingsBackup buildPreviewGroupsForSettings:self.mutableSettings];
    self.visibleGroups = self.allGroups;
}

#pragma mark Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *q = searchController.searchBar.text ?: @"";
    self.searchText = q;
    if (q.length == 0) {
        self.visibleGroups = self.allGroups;
    } else {
        NSMutableArray *out = [NSMutableArray array];
        for (SCIBackupPreviewGroup *g in self.allGroups) {
            NSMutableArray *matches = [NSMutableArray array];
            for (SCIBackupPreviewRow *r in g.rows) {
                if ([r.title rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [matches addObject:r];
                }
            }
            if (matches.count) {
                SCIBackupPreviewGroup *clone = [SCIBackupPreviewGroup new];
                clone.title = g.title;
                clone.rows = matches;
                clone.collapsed = NO; // force-expand while searching
                [out addObject:clone];
            }
        }
        self.visibleGroups = out;
    }
    [self.tableView reloadData];
}

#pragma mark Table data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.visibleGroups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SCIBackupPreviewGroup *g = self.visibleGroups[section];
    return g.collapsed ? 0 : g.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCIBackupPreviewGroup *g = self.visibleGroups[indexPath.section];
    SCIBackupPreviewRow *row = g.rows[indexPath.row];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"row"];
    }
    cell.textLabel.text = row.title;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (row.kind == SCIBackupPreviewRowKindSwitch && row.defaultsKey.length) {
        UISwitch *sw = [[UISwitch alloc] init];
        id raw = self.mutableSettings[row.defaultsKey];
        sw.on = [raw respondsToSelector:@selector(boolValue)] ? [raw boolValue] : NO;
        sw.enabled = self.editMode;
        objc_setAssociatedObject(sw, "sci_key", row.defaultsKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if (row.kind == SCIBackupPreviewRowKindMenu && row.defaultsKey.length) {
        cell.accessoryView = nil;
        cell.detailTextLabel.text = row.value;
        cell.accessoryType = self.editMode ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        cell.selectionStyle = self.editMode ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.detailTextLabel.text = row.value;
    }
    return cell;
}

- (void)switchToggled:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "sci_key");
    if (!key.length) return;
    self.mutableSettings[key] = @(sender.isOn);
}

- (void)toggleEditMode {
    self.editMode = !self.editMode;
    self.editToggleItem.title = self.editMode ? @"Done" : @"Edit";
    self.editToggleItem.style = self.editMode ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.editMode) return;

    SCIBackupPreviewGroup *g = self.visibleGroups[indexPath.section];
    SCIBackupPreviewRow *row = g.rows[indexPath.row];
    if (row.kind != SCIBackupPreviewRowKindMenu || !row.menuOptions.count || !row.defaultsKey.length) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:row.title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *currentValue = [self.mutableSettings[row.defaultsKey] description];
    for (NSDictionary *opt in row.menuOptions) {
        NSString *optTitle = opt[@"title"];
        NSString *optValue = opt[@"value"];
        if (!optTitle.length || !optValue.length) continue;
        NSString *display = [optValue isEqualToString:currentValue]
            ? [NSString stringWithFormat:@"%@ ✓", optTitle]
            : optTitle;
        [sheet addAction:[UIAlertAction actionWithTitle:display
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) {
            self.mutableSettings[row.defaultsKey] = optValue;
            row.value = optTitle;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    sheet.popoverPresentationController.sourceView = cell;
    sheet.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark Section headers (collapsible)

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SCIBackupPreviewGroup *g = self.visibleGroups[section];
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor clearColor];

    UILabel *label = [[UILabel alloc] init];
    label.text = g.title;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    label.textColor = [UIColor secondaryLabelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *chev = [[UIImageView alloc] init];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
    chev.image = [[UIImage systemImageNamed:(g.collapsed ? @"chevron.right" : @"chevron.down")]
                    imageByApplyingSymbolConfiguration:cfg];
    chev.tintColor = [UIColor secondaryLabelColor];
    chev.translatesAutoresizingMaskIntoConstraints = NO;

    [header addSubview:label];
    [header addSubview:chev];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:chev.leadingAnchor constant:-8],
        [chev.trailingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.trailingAnchor],
        [chev.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [header.heightAnchor constraintGreaterThanOrEqualToConstant:36],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sectionHeaderTapped:)];
    header.tag = section;
    [header addGestureRecognizer:tap];
    return header;
}

- (void)sectionHeaderTapped:(UITapGestureRecognizer *)tap {
    NSInteger section = tap.view.tag;
    if (section < 0 || section >= (NSInteger)self.visibleGroups.count) return;
    SCIBackupPreviewGroup *g = self.visibleGroups[section];
    g.collapsed = !g.collapsed;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section]
                  withRowAnimation:UITableViewRowAnimationFade];
    UIView *header = [self.tableView headerViewForSection:section] ?: [self tableView:self.tableView viewForHeaderInSection:section];
    for (UIView *sub in header.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
            ((UIImageView *)sub).image = [[UIImage systemImageNamed:(g.collapsed ? @"chevron.right" : @"chevron.down")]
                                            imageByApplyingSymbolConfiguration:cfg];
        }
    }
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)runPrimary {
    if (self.primaryAction) self.primaryAction(self);
}

@end

@class SCIBackupPreviewGroup;
@interface SCISettingsBackup ()
+ (void)showError:(NSString *)message;
+ (void)showSuccessHUD:(NSString *)message;
+ (NSData *)decodeQRDataFromImage:(UIImage *)image;
+ (void)presentApplyConfirmationForData:(NSData *)data;
+ (void)pickFromFiles;
+ (void)pickFromPhotos;
+ (NSArray<SCIBackupPreviewGroup *> *)buildPreviewGroupsForSettings:(NSDictionary *)values;
@end

#pragma mark - Helper singleton (delegates for pickers)

@interface SCIBackupHelper : NSObject <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic) BOOL expectingExportPick;
@end

@implementation SCIBackupHelper

+ (instancetype)shared {
    static SCIBackupHelper *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[SCIBackupHelper alloc] init]; });
    return s;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (self.expectingExportPick) {
        self.expectingExportPick = NO;
        [SCISettingsBackup showSuccessHUD:@"Settings exported"];
        return;
    }
    NSURL *url = urls.firstObject;
    if (!url) return;
    BOOL access = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (access) [url stopAccessingSecurityScopedResource];
    if (!data) {
        [SCISettingsBackup showError:@"Could not read file."];
        return;
    }
    [SCISettingsBackup presentApplyConfirmationForData:data];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.expectingExportPick = NO;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        NSData *data = [SCISettingsBackup decodeQRDataFromImage:image];
        if (!data) {
            [SCISettingsBackup showError:@"No RyukGram QR code found in the selected photo."];
            return;
        }
        [SCISettingsBackup presentApplyConfirmationForData:data];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - SCISettingsBackup

@implementation SCISettingsBackup

#pragma mark Key discovery

+ (NSSet<NSString *> *)allPrefKeys {
    NSMutableSet *keys = [NSMutableSet set];
    [self collectKeysFromSections:[SCITweakSettings sections] into:keys];
    return keys;
}

+ (void)collectKeysFromSections:(NSArray *)sections into:(NSMutableSet *)keys {
    for (id section in sections) {
        if (![section isKindOfClass:[NSDictionary class]]) continue;
        NSArray *rows = ((NSDictionary *)section)[@"rows"];
        for (id row in rows) {
            if (![row isKindOfClass:[SCISetting class]]) continue;
            SCISetting *s = row;
            if (s.defaultsKey.length) [keys addObject:s.defaultsKey];
            if (s.baseMenu) [self collectKeysFromMenu:s.baseMenu into:keys];
            if (s.navSections) [self collectKeysFromSections:s.navSections into:keys];
        }
    }
}

+ (void)collectKeysFromMenu:(UIMenu *)menu into:(NSMutableSet *)keys {
    for (id child in menu.children) {
        if ([child isKindOfClass:[UIMenu class]]) {
            [self collectKeysFromMenu:child into:keys];
        } else if ([child isKindOfClass:[UICommand class]]) {
            id pl = [(UICommand *)child propertyList];
            if ([pl isKindOfClass:[NSDictionary class]]) {
                NSString *k = ((NSDictionary *)pl)[@"defaultsKey"];
                if ([k isKindOfClass:[NSString class]] && k.length) [keys addObject:k];
            }
        }
    }
}

#pragma mark Snapshot / serialize / apply

+ (NSDictionary *)snapshotCurrentSettings {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    for (NSString *key in [self allPrefKeys]) {
        id v = [d objectForKey:key];
        if (v && [NSJSONSerialization isValidJSONObject:@{@"v": v}]) {
            out[key] = v;
        }
    }
    return out;
}

+ (NSData *)serializeSettings:(NSDictionary *)settings {
    NSDictionary *wrapped = @{
        @"app": @"RyukGram",
        @"version": SCIVersionString ?: @"unknown",
        @"settings": settings ?: @{}
    };
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:wrapped
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&err];
    if (err) NSLog(@"[SCInsta] backup: serialize failed: %@", err);
    return data;
}

+ (NSDictionary *)parseSettingsFromData:(NSData *)data {
    if (!data) return nil;
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (err || ![obj isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *root = obj;
    NSDictionary *settings = root[@"settings"];
    if ([settings isKindOfClass:[NSDictionary class]]) return settings;
    return root;
}

+ (void)applySettings:(NSDictionary *)settings {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSSet *known = [self allPrefKeys];
    for (NSString *key in known) [d removeObjectForKey:key];
    for (NSString *key in settings) {
        if ([known containsObject:key]) {
            [d setObject:settings[key] forKey:key];
        }
    }
    [d synchronize];
}

#pragma mark QR

+ (UIImage *)qrCodeForData:(NSData *)data {
    if (!data) return nil;
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (!filter) return nil;
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *output = filter.outputImage;
    if (!output) return nil;
    output = [output imageByApplyingTransform:CGAffineTransformMakeScale(8, 8)];
    return [UIImage imageWithCIImage:output];
}

+ (NSData *)decodeQRDataFromImage:(UIImage *)image {
    if (!image) return nil;
    CIImage *ci = image.CIImage;
    if (!ci && image.CGImage) ci = [CIImage imageWithCGImage:image.CGImage];
    if (!ci) return nil;
    CIDetector *det = [CIDetector detectorOfType:CIDetectorTypeQRCode
                                         context:nil
                                         options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    NSArray *features = [det featuresInImage:ci];
    for (CIQRCodeFeature *f in features) {
        if ([f isKindOfClass:[CIQRCodeFeature class]] && f.messageString) {
            return [f.messageString dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    return nil;
}

#pragma mark Helpers

+ (NSString *)timestampString {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMdd-HHmmss";
    return [fmt stringFromDate:[NSDate date]];
}

+ (NSString *)prettyJSONForSettings:(NSDictionary *)settings {
    NSData *d = [self serializeSettings:settings];
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"";
}

#pragma mark Human-readable preview groups

+ (NSArray<SCIBackupPreviewGroup *> *)buildPreviewGroupsForSettings:(NSDictionary *)values {
    NSMutableArray<SCIBackupPreviewGroup *> *groups = [NSMutableArray array];
    [self collectGroupsFromSections:[SCITweakSettings sections]
                          breadcrumb:@""
                              values:values
                                 out:groups];

    NSSet *known = [self allPrefKeys];
    NSMutableArray *unknown = [NSMutableArray array];
    for (NSString *k in values) {
        if (![known containsObject:k]) [unknown addObject:k];
    }
    if (unknown.count) {
        [unknown sortUsingSelector:@selector(compare:)];
        SCIBackupPreviewGroup *g = [SCIBackupPreviewGroup new];
        g.title = @"OTHER";
        g.rows = [NSMutableArray array];
        for (NSString *k in unknown) {
            SCIBackupPreviewRow *r = [SCIBackupPreviewRow new];
            r.title = k;
            r.value = [self displayStringForValue:values[k]];
            r.kind = SCIBackupPreviewRowKindReadOnly;
            [g.rows addObject:r];
        }
        [groups addObject:g];
    }
    return groups;
}

+ (void)collectGroupsFromSections:(NSArray *)sections
                       breadcrumb:(NSString *)breadcrumb
                           values:(NSDictionary *)values
                              out:(NSMutableArray<SCIBackupPreviewGroup *> *)out {
    for (id sectionObj in sections) {
        if (![sectionObj isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *section = sectionObj;
        NSString *sectionHeader = section[@"header"] ?: @"";
        NSArray *rows = section[@"rows"];

        SCIBackupPreviewGroup *currentGroup = nil;

        for (id rowObj in rows) {
            if (![rowObj isKindOfClass:[SCISetting class]]) continue;
            SCISetting *s = rowObj;

            if (s.navSections) {
                NSString *childBreadcrumb = breadcrumb.length
                    ? [NSString stringWithFormat:@"%@ › %@", breadcrumb, s.title]
                    : s.title;
                [self collectGroupsFromSections:s.navSections
                                     breadcrumb:childBreadcrumb
                                         values:values
                                            out:out];
                continue;
            }

            BOOL isMenu = (s.type == SCITableCellMenu);
            if (!s.defaultsKey.length && !isMenu) continue;

            SCIBackupPreviewRow *r = [SCIBackupPreviewRow new];
            r.title = s.title.length ? s.title : (s.defaultsKey ?: @"?");
            r.defaultsKey = s.defaultsKey;

            if (s.type == SCITableCellSwitch) {
                r.kind = SCIBackupPreviewRowKindSwitch;
                id raw = values[s.defaultsKey];
                BOOL on = [raw respondsToSelector:@selector(boolValue)] ? [raw boolValue] : NO;
                r.value = on ? @"On" : @"Off";
            } else if (s.type == SCITableCellStepper) {
                r.kind = SCIBackupPreviewRowKindReadOnly;
                id raw = values[s.defaultsKey];
                NSString *display = @"—";
                if (raw) {
                    double d = [raw doubleValue];
                    if (fmod(d, 1.0) == 0.0) display = [NSString stringWithFormat:@"%lld", (long long)d];
                    else display = [NSString stringWithFormat:@"%g", d];
                    if (s.label.length) display = [display stringByAppendingFormat:@" %@", s.label];
                }
                r.value = display;
            } else if (isMenu) {
                r.kind = SCIBackupPreviewRowKindMenu;
                NSMutableArray *opts = [NSMutableArray array];
                NSString *defKey = nil;
                [self collectOptionsFromMenu:s.baseMenu defaultsKeyOut:&defKey into:opts];
                r.menuOptions = opts;
                r.defaultsKey = defKey ?: s.defaultsKey;
                NSString *menuTitle = [self menuTitleForBaseMenu:s.baseMenu values:values resolvedKey:NULL];
                r.value = menuTitle ?: @"—";
            } else {
                r.kind = SCIBackupPreviewRowKindReadOnly;
                r.value = [self displayStringForValue:values[s.defaultsKey]];
            }

            if (!currentGroup) {
                currentGroup = [SCIBackupPreviewGroup new];
                NSMutableString *hdr = [NSMutableString string];
                if (breadcrumb.length) [hdr appendString:breadcrumb];
                if (sectionHeader.length) {
                    if (hdr.length) [hdr appendString:@" — "];
                    [hdr appendString:sectionHeader];
                }
                if (!hdr.length) hdr = [NSMutableString stringWithString:@"General"];
                currentGroup.title = [hdr uppercaseString];
                currentGroup.rows = [NSMutableArray array];
                [out addObject:currentGroup];
            }
            [currentGroup.rows addObject:r];
        }
    }
}

+ (NSString *)displayStringForValue:(id)raw {
    if (!raw || raw == [NSNull null]) return @"—";
    if ([raw isKindOfClass:[NSNumber class]]) {
        NSNumber *n = raw;
        const char *t = n.objCType;
        if (t && strcmp(t, "c") == 0) return n.boolValue ? @"On" : @"Off";
        return n.stringValue;
    }
    if ([raw isKindOfClass:[NSString class]]) return raw;
    return [NSString stringWithFormat:@"%@", raw];
}

+ (NSString *)menuTitleForBaseMenu:(UIMenu *)menu values:(NSDictionary *)values resolvedKey:(id *)outRaw {
    if (!menu) return nil;
    NSString *defaultsKey = nil;
    UICommand *match = [self findMatchingCommandInMenu:menu values:values defaultsKeyOut:&defaultsKey];
    if (defaultsKey && outRaw) *outRaw = values[defaultsKey];
    if (match) return match.title;
    if (defaultsKey) return [self displayStringForValue:values[defaultsKey]];
    return nil;
}

+ (void)collectOptionsFromMenu:(UIMenu *)menu defaultsKeyOut:(NSString **)outKey into:(NSMutableArray *)out {
    if (!menu) return;
    for (id child in menu.children) {
        if ([child isKindOfClass:[UIMenu class]]) {
            [self collectOptionsFromMenu:child defaultsKeyOut:outKey into:out];
        } else if ([child isKindOfClass:[UICommand class]]) {
            UICommand *cmd = child;
            id pl = cmd.propertyList;
            if ([pl isKindOfClass:[NSDictionary class]]) {
                NSString *k = ((NSDictionary *)pl)[@"defaultsKey"];
                NSString *v = ((NSDictionary *)pl)[@"value"];
                if ([k isKindOfClass:[NSString class]] && k.length &&
                    [v isKindOfClass:[NSString class]] && v.length) {
                    if (outKey && !*outKey) *outKey = k;
                    [out addObject:@{ @"value": v, @"title": cmd.title ?: v }];
                }
            }
        }
    }
}

+ (UICommand *)findMatchingCommandInMenu:(UIMenu *)menu values:(NSDictionary *)values defaultsKeyOut:(NSString **)outKey {
    for (id child in menu.children) {
        if ([child isKindOfClass:[UIMenu class]]) {
            UICommand *m = [self findMatchingCommandInMenu:child values:values defaultsKeyOut:outKey];
            if (m) return m;
        } else if ([child isKindOfClass:[UICommand class]]) {
            UICommand *cmd = child;
            id pl = cmd.propertyList;
            if ([pl isKindOfClass:[NSDictionary class]]) {
                NSString *k = ((NSDictionary *)pl)[@"defaultsKey"];
                NSString *v = ((NSDictionary *)pl)[@"value"];
                if ([k isKindOfClass:[NSString class]] && k.length) {
                    if (outKey && !*outKey) *outKey = k;
                    id current = values[k];
                    if (current && v && [[NSString stringWithFormat:@"%@", current] isEqualToString:v]) {
                        return cmd;
                    }
                }
            }
        }
    }
    return nil;
}

+ (void)showSuccessHUD:(NSString *)message {
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb prepare];
    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];

    UIView *host = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { host = w; break; }
    }
    if (!host) host = topMostController().view;
    if (!host) return;

    JGProgressHUD *HUD = [[JGProgressHUD alloc] init];
    HUD.textLabel.text = message;
    HUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
    [HUD showInView:host];
    [HUD dismissAfterDelay:1.5];
}

+ (void)showError:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Import failed"
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [topMostController() presentViewController:a animated:YES completion:nil];
}

#pragma mark Export

+ (void)presentExport {
    NSDictionary *snap = [self snapshotCurrentSettings];

    SCIBackupPreviewVC *vc = [[SCIBackupPreviewVC alloc] init];
    vc.title = @"Export settings";
    vc.mutableSettings = [snap mutableCopy];
    vc.qrImage = [self qrCodeForData:[self serializeSettings:snap]];
    vc.primaryActionTitle = @"Save";
    vc.primaryAction = ^(SCIBackupPreviewVC *previewVC) {
        NSData *data = [self serializeSettings:previewVC.mutableSettings];
        UIImage *qr = [self qrCodeForData:data];

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Save settings"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Save as JSON file"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) {
            NSString *fname = [NSString stringWithFormat:@"ryukgram-settings-%@.json", [self timestampString]];
            NSURL *tmp = [[NSFileManager defaultManager].temporaryDirectory URLByAppendingPathComponent:fname];
            NSError *err = nil;
            [data writeToURL:tmp options:NSDataWritingAtomic error:&err];
            if (err) { [self showError:@"Could not write temporary file."]; return; }
            UIDocumentPickerViewController *p =
                [[UIDocumentPickerViewController alloc] initForExportingURLs:@[tmp]];
            SCIBackupHelper *helper = [SCIBackupHelper shared];
            helper.expectingExportPick = YES;
            p.delegate = helper;
            [previewVC presentViewController:p animated:YES completion:nil];
        }]];
        if (qr) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"Save QR code as image"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *_) {
                // Flatten CIImage-backed QR into a CGImage-backed UIImage so the share sheet can save it.
                UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
                fmt.scale = 1.0;
                CGSize sz = CGSizeMake(900, 1020);
                UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:sz format:fmt];
                UIImage *flat = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
                    [[UIColor whiteColor] setFill];
                    [ctx fillRect:CGRectMake(0, 0, sz.width, sz.height)];
                    NSString *title = @"RyukGram settings";
                    NSString *subtitle = [NSString stringWithFormat:@"Scan in RyukGram → Backup & Restore → Import\n%@", SCIVersionString ?: @""];
                    NSDictionary *titleAttrs = @{
                        NSFontAttributeName: [UIFont systemFontOfSize:54 weight:UIFontWeightBold],
                        NSForegroundColorAttributeName: [UIColor blackColor],
                    };
                    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
                    p.alignment = NSTextAlignmentCenter;
                    NSDictionary *subAttrs = @{
                        NSFontAttributeName: [UIFont systemFontOfSize:22 weight:UIFontWeightRegular],
                        NSForegroundColorAttributeName: [UIColor darkGrayColor],
                        NSParagraphStyleAttributeName: p,
                    };
                    NSMutableParagraphStyle *pc = [NSMutableParagraphStyle new];
                    pc.alignment = NSTextAlignmentCenter;
                    NSDictionary *titleAttrsCentered = @{
                        NSFontAttributeName: titleAttrs[NSFontAttributeName],
                        NSForegroundColorAttributeName: titleAttrs[NSForegroundColorAttributeName],
                        NSParagraphStyleAttributeName: pc,
                    };
                    [title drawInRect:CGRectMake(40, 30, sz.width - 80, 70) withAttributes:titleAttrsCentered];
                    [subtitle drawInRect:CGRectMake(40, 100, sz.width - 80, 60) withAttributes:subAttrs];
                    [qr drawInRect:CGRectMake(60, 180, sz.width - 120, sz.width - 120)];
                }];
                UIActivityViewController *share =
                    [[UIActivityViewController alloc] initWithActivityItems:@[flat] applicationActivities:nil];
                share.completionWithItemsHandler = ^(UIActivityType _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                    if (completed) [SCISettingsBackup showSuccessHUD:@"QR code saved"];
                };
                share.popoverPresentationController.sourceView = previewVC.view;
                share.popoverPresentationController.sourceRect = CGRectMake(previewVC.view.bounds.size.width / 2,
                                                                            previewVC.view.bounds.size.height / 2,
                                                                            1, 1);
                [previewVC presentViewController:share animated:YES completion:nil];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        sheet.popoverPresentationController.barButtonItem = previewVC.navigationItem.rightBarButtonItem;
        [previewVC presentViewController:sheet animated:YES completion:nil];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [topMostController() presentViewController:nav animated:YES completion:nil];
}

#pragma mark Import

+ (void)presentImport {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Import settings"
                                                                   message:@"Importing will reset all RyukGram settings to defaults and apply the imported values."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"From Files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self pickFromFiles];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"From Photos (QR code)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self pickFromPhotos];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *top = topMostController();
    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(top.view.bounds.size.width / 2,
                                                                top.view.bounds.size.height / 2,
                                                                1, 1);
    [top presentViewController:sheet animated:YES completion:nil];
}

+ (void)pickFromFiles {
    UIDocumentPickerViewController *p =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json", @"public.text", @"public.data"]
                                                                inMode:UIDocumentPickerModeImport];
    p.delegate = [SCIBackupHelper shared];
    p.allowsMultipleSelection = NO;
    [topMostController() presentViewController:p animated:YES completion:nil];
}

+ (void)pickFromPhotos {
    UIImagePickerController *p = [[UIImagePickerController alloc] init];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.delegate = [SCIBackupHelper shared];
    [topMostController() presentViewController:p animated:YES completion:nil];
}

+ (void)presentApplyConfirmationForData:(NSData *)data {
    NSDictionary *settings = [self parseSettingsFromData:data];
    if (!settings) {
        [self showError:@"File is not a valid RyukGram settings export."];
        return;
    }

    SCIBackupPreviewVC *vc = [[SCIBackupPreviewVC alloc] init];
    vc.title = @"Import preview";
    vc.mutableSettings = [settings mutableCopy];
    vc.qrImage = nil;
    vc.primaryActionTitle = @"Apply";
    vc.primaryAction = ^(SCIBackupPreviewVC *previewVC) {
        UIAlertController *confirm =
            [UIAlertController alertControllerWithTitle:@"Apply imported settings?"
                                                message:@"All RyukGram settings will be reset to defaults and the imported values applied. The app will need to restart for some changes to take effect."
                                         preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
            [SCISettingsBackup applySettings:previewVC.mutableSettings];
            [previewVC dismissViewControllerAnimated:YES completion:^{
                [SCISettingsBackup showSuccessHUD:@"Settings imported"];
                [SCIUtils showRestartConfirmation];
            }];
        }]];
        [previewVC presentViewController:confirm animated:YES completion:nil];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [topMostController() presentViewController:nav animated:YES completion:nil];
}

@end
