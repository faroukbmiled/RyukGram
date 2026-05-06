#import "SCIDateFormatPickerVC.h"
#import "../Utils.h"
#import "../Features/General/SCIDateFormatEntries.h"

static NSString *const kFmtKey = @"feed_date_format";
static NSString *const kSecKey = @"feed_date_show_seconds";

// [key, pattern, pattern_with_seconds]
static NSArray<NSArray *> *sciDateFormatOptions(void) {
    static NSArray *opts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        opts = @[
            @[@"default",       @"",                              @""],
            @[@"short",         @"MMM d",                         @"MMM d"],
            @[@"medium",        @"MMM d, yyyy",                   @"MMM d, yyyy"],
            @[@"full",          @"MMM d, yyyy 'at' h:mm a",       @"MMM d, yyyy 'at' h:mm:ss a"],
            @[@"time_12",       @"MMM d 'at' h:mm a",             @"MMM d 'at' h:mm:ss a"],
            @[@"time_24",       @"MMM d 'at' HH:mm",              @"MMM d 'at' HH:mm:ss"],
            @[@"dd_mmm",        @"dd-MMM-yyyy 'at' h:mm a",       @"dd-MMM-yyyy 'at' h:mm:ss a"],
            @[@"day_slash",     @"dd/MM/yyyy h:mm a",             @"dd/MM/yyyy h:mm:ss a"],
            @[@"month_slash",   @"MM/dd/yyyy h:mm a",             @"MM/dd/yyyy h:mm:ss a"],
            @[@"euro",          @"dd.MM.yyyy HH:mm",              @"dd.MM.yyyy HH:mm:ss"],
            @[@"iso",           @"yyyy-MM-dd",                    @"yyyy-MM-dd"],
            @[@"iso_time",      @"yyyy-MM-dd HH:mm",              @"yyyy-MM-dd HH:mm:ss"],
        ];
    });
    return opts;
}

// [pref_key, label]
static NSArray<NSArray<NSString *> *> *sciSurfaceEntries(void) {
    static NSArray *entries = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *m = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        #define SCI_EMIT(NAME, SEL_, LABEL, ARITY, PREF) \
            if (strlen(LABEL) && ![seen containsObject:@PREF]) { \
                [seen addObject:@PREF]; \
                [m addObject:@[@PREF, @LABEL]]; \
            }
        SCI_DATE_FORMAT_ENTRIES(SCI_EMIT)
        #undef SCI_EMIT
        entries = [m copy];
    });
    return entries;
}

static NSDate *sciRefDate(void) {
    static NSDate *ref = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ref = [NSDate dateWithTimeIntervalSince1970:1736348730]; });
    return ref;
}

static NSString *sciExampleForKey(NSString *key) {
    if (!key.length || [key isEqualToString:@"default"]) return @"Default";
    BOOL sec = [[NSUserDefaults standardUserDefaults] boolForKey:kSecKey];
    for (NSArray *opt in sciDateFormatOptions()) {
        if ([opt[0] isEqualToString:key]) {
            NSString *pattern = sec ? opt[2] : opt[1];
            if (!pattern.length) return SCILocalized(@"Default");
            NSDateFormatter *df = [NSDateFormatter new];
            df.dateFormat = pattern;
            return [df stringFromDate:sciRefDate()];
        }
    }
    return SCILocalized(@"Default");
}

@implementation SCIDateFormatPickerVC {
    UITableView *_tableView;
}

+ (NSString *)currentFormatExample {
    return sciExampleForKey([SCIUtils getStringPref:kFmtKey]);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"Date format");
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];
}

// Sections: 0 = format options, 1 = show seconds, 2 = surface toggles
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return (NSInteger)sciDateFormatOptions().count;
    if (s == 1) return 1;
    return (NSInteger)sciSurfaceEntries().count;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return SCILocalized(@"Format");
    if (s == 2) return SCILocalized(@"Apply to");
    return @"";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 2) return SCILocalized(@"Toggle each NSDate formatter IG uses. Different surfaces (feed, comments, stories, DMs) go through different methods — enable the ones you want the custom format applied to.");
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 1) {
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"sec"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sec"];
        cell.textLabel.text = SCILocalized(@"Show seconds");
        UISwitch *sw = [UISwitch new];
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kSecKey];
        [sw addTarget:self action:@selector(secondsToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    if (ip.section == 2) {
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"surf"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"surf"];
        NSArray *entry = sciSurfaceEntries()[ip.row];
        cell.textLabel.text = SCILocalized(entry[1]);
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        UISwitch *sw = [UISwitch new];
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:entry[0]];
        sw.tag = ip.row;
        [sw addTarget:self action:@selector(surfaceToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"df"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"df"];

    NSString *key = sciDateFormatOptions()[ip.row][0];
    cell.textLabel.text = sciExampleForKey(key);
    cell.textLabel.font = [UIFont systemFontOfSize:16];

    NSString *current = [SCIUtils getStringPref:kFmtKey];
    if (!current.length) current = @"default";
    cell.accessoryType = [current isEqualToString:key]
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 0) return;
    [[NSUserDefaults standardUserDefaults] setObject:sciDateFormatOptions()[ip.row][0] forKey:kFmtKey];
    [tv reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)secondsToggled:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kSecKey];
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)surfaceToggled:(UISwitch *)sw {
    NSArray *entry = sciSurfaceEntries()[sw.tag];
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:entry[0]];
}

@end
