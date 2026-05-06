#import "SCIFakeLocationSettingsVC.h"
#import "SCIFakeLocationPickerVC.h"
#import "../Utils.h"

static NSString *const kEnabled    = @"fake_location_enabled";
static NSString *const kShowBtn    = @"show_fake_location_map_button";
static NSString *const kLat        = @"fake_location_lat";
static NSString *const kLon        = @"fake_location_lon";
static NSString *const kName       = @"fake_location_name";
static NSString *const kPresets    = @"fake_location_presets";

@interface SCIFakeLocationSettingsVC ()
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation SCIFakeLocationSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"Fake location");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

// MARK: - Storage helpers

- (NSArray<NSDictionary *> *)presets {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] objectForKey:kPresets];
    return [raw isKindOfClass:[NSArray class]] ? raw : @[];
}

- (void)setPresets:(NSArray<NSDictionary *> *)presets {
    [[NSUserDefaults standardUserDefaults] setObject:presets forKey:kPresets];
}

- (void)applyCoord:(double)lat lon:(double)lon name:(NSString *)name {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:@(lat) forKey:kLat];
    [d setObject:@(lon) forKey:kLon];
    [d setObject:(name ?: @"") forKey:kName];
    [self.tableView reloadData];
}

// Sections: 0 toggle • 1 current + select • 2 presets + add

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return 2;
    if (s == 1) return 2;
    return self.presets.count + 1;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (s == 1) return SCILocalized(@"Current location");
    if (s == 2) return SCILocalized(@"Saved locations");
    return nil;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 0) return SCILocalized(@"When on, all CoreLocation requests inside Instagram return the location below. Toggle the map button to show or hide the quick toggle on the Friends Map view.");
    if (s == 2) return SCILocalized(@"Saved presets are reusable. Tap a preset to make it the active location.");
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        if (ip.row == 0) {
            UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"sw"];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sw"];
            cell.textLabel.text = SCILocalized(@"Enable fake location");
            UISwitch *sw = [UISwitch new];
            sw.on = [SCIUtils getBoolPref:kEnabled];
            [sw addTarget:self action:@selector(masterToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"swShow"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"swShow"];
        cell.textLabel.text = SCILocalized(@"Show map button");
        UISwitch *sw = [UISwitch new];
        sw.on = [SCIUtils getBoolPref:kShowBtn];
        [sw addTarget:self action:@selector(showBtnToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    if (ip.section == 1) {
        if (ip.row == 0) {
            UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cur"];
            if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cur"];
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            double lat = [[d objectForKey:kLat] doubleValue];
            double lon = [[d objectForKey:kLon] doubleValue];
            NSString *name = [d objectForKey:kName] ?: @"";
            cell.textLabel.text = name.length ? name : SCILocalized(@"(unset)");
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.5f, %.5f", lat, lon];
            cell.detailTextLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
            cell.imageView.image = [UIImage systemImageNamed:@"location.fill"];
            cell.imageView.tintColor = [UIColor systemGreenColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            return cell;
        }
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"sel"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sel"];
        cell.textLabel.text = SCILocalized(@"Select location on map");
        cell.textLabel.textColor = [UIColor systemBlueColor];
        cell.imageView.image = [UIImage systemImageNamed:@"map"];
        cell.imageView.tintColor = [UIColor systemBlueColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    // Presets
    NSArray<NSDictionary *> *presets = self.presets;
    if (ip.row < (NSInteger)presets.count) {
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"p"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"p"];
        NSDictionary *p = presets[ip.row];
        cell.textLabel.text = p[@"name"] ?: SCILocalized(@"Preset");
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.5f, %.5f",
            [p[@"lat"] doubleValue], [p[@"lon"] doubleValue]];
        cell.detailTextLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
        cell.imageView.image = [UIImage systemImageNamed:@"mappin.circle.fill"];
        cell.imageView.tintColor = [UIColor systemRedColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"add"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"add"];
    cell.textLabel.text = SCILocalized(@"Add preset");
    cell.textLabel.textColor = [UIColor systemBlueColor];
    cell.imageView.image = [UIImage systemImageNamed:@"plus.circle.fill"];
    cell.imageView.tintColor = [UIColor systemBlueColor];
    return cell;
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip {
    return ip.section == 2 && ip.row < (NSInteger)self.presets.count;
}

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *presets = [self.presets mutableCopy];
    [presets removeObjectAtIndex:ip.row];
    [self setPresets:presets];
    [tv deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    if (ip.section == 1 && ip.row == 1) {
        [self openPickerForCurrent];
    } else if (ip.section == 2) {
        NSArray<NSDictionary *> *presets = self.presets;
        if (ip.row < (NSInteger)presets.count) {
            NSDictionary *p = presets[ip.row];
            [self applyCoord:[p[@"lat"] doubleValue] lon:[p[@"lon"] doubleValue] name:p[@"name"]];
        } else {
            [self openPickerForNewPreset];
        }
    }
}

// MARK: - Actions

- (void)masterToggled:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kEnabled];
}

- (void)showBtnToggled:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kShowBtn];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SCIFakeLocationMapBtnPrefChanged" object:nil];
}

- (void)openPickerForCurrent {
    SCIFakeLocationPickerVC *vc = [SCIFakeLocationPickerVC new];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    vc.initialCoord = CLLocationCoordinate2DMake([[d objectForKey:kLat] doubleValue],
                                                 [[d objectForKey:kLon] doubleValue]);
    vc.titleText = SCILocalized(@"Set current location");
    __weak typeof(self) weakSelf = self;
    vc.onPick = ^(double lat, double lon, NSString *name) {
        [weakSelf applyCoord:lat lon:lon name:name];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openPickerForNewPreset {
    SCIFakeLocationPickerVC *vc = [SCIFakeLocationPickerVC new];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    vc.initialCoord = CLLocationCoordinate2DMake([[d objectForKey:kLat] doubleValue],
                                                 [[d objectForKey:kLon] doubleValue]);
    vc.titleText = SCILocalized(@"Add preset");
    __weak typeof(self) weakSelf = self;
    vc.onPick = ^(double lat, double lon, NSString *name) {
        // Confirm name via simple alert
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:SCILocalized(@"Save preset")
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = SCILocalized(@"Name");
            tf.text = name;
            tf.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            NSString *finalName = alert.textFields.firstObject.text.length ? alert.textFields.firstObject.text : name;
            NSDictionary *preset = @{@"name": finalName ?: @"", @"lat": @(lat), @"lon": @(lon)};
            NSMutableArray *presets = [weakSelf.presets mutableCopy];
            [presets addObject:preset];
            [weakSelf setPresets:presets];
            [weakSelf.tableView reloadData];
        }]];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

@end
