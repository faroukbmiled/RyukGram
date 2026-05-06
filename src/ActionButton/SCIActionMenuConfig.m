#import "SCIActionMenuConfig.h"
#import "../Utils.h"

NSString *const SCIActionMenuConfigDidChangeNotification = @"SCIActionMenuConfigDidChangeNotification";

static NSString *const kCfgVersion       = @"v";
static NSString *const kCfgSections      = @"sections";
static NSString *const kCfgDisabled      = @"disabled";
static NSString *const kCfgShowDate      = @"show_date";
static NSString *const kCfgDefaultTap    = @"default_tap";
static NSString *const kCfgDefaultCopy   = @"default_copy_info";
static NSInteger  const kCfgCurrentVer   = 1;

@interface SCIActionMenuConfig ()
@property (nonatomic, assign, readwrite) SCIActionSource source;
@property (nonatomic, strong) NSMutableArray<SCIActionConfigSection *> *sectionsStorage;
@property (nonatomic, strong) NSMutableSet<NSString *> *disabledStorage;
@end

@implementation SCIActionMenuConfig

// MARK: - Cache

+ (NSMutableDictionary<NSNumber *, SCIActionMenuConfig *> *)cache {
    static NSMutableDictionary *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [NSMutableDictionary dictionary]; });
    return c;
}

+ (instancetype)configForSource:(SCIActionSource)source {
    @synchronized ([self cache]) {
        SCIActionMenuConfig *cfg = [self cache][@(source)];
        if (cfg) return cfg;
        cfg = [[SCIActionMenuConfig alloc] initForSource:source];
        [self cache][@(source)] = cfg;
        return cfg;
    }
}

+ (void)reloadAll {
    @synchronized ([self cache]) { [[self cache] removeAllObjects]; }
}

// MARK: - Init

- (instancetype)initForSource:(SCIActionSource)source {
    self = [super init];
    if (!self) return nil;
    _source = source;
    _sectionsStorage = [NSMutableArray array];
    _disabledStorage = [NSMutableSet set];
    [self load];
    return self;
}

// MARK: - Load

- (void)load {
    NSDictionary *dict = [SCIUtils getDictPref:[SCIActionCatalog prefKeyForSource:_source]];
    BOOL hasStored = ([dict isKindOfClass:[NSDictionary class]] && dict.count > 0);

    NSArray<SCIActionConfigSection *> *defaultSections = [SCIActionCatalog defaultSectionsForSource:_source];

    // Sections
    NSMutableArray<SCIActionConfigSection *> *loaded = [NSMutableArray array];
    if (hasStored) {
        NSArray *raw = dict[kCfgSections];
        if ([raw isKindOfClass:[NSArray class]]) {
            for (id v in raw) {
                SCIActionConfigSection *s = [SCIActionConfigSection sectionFromDictionary:v];
                if (s) [loaded addObject:s];
            }
        }
    }
    if (loaded.count == 0) {
        for (SCIActionConfigSection *s in defaultSections) [loaded addObject:[s copy]];
    } else {
        // Backfill section-level metadata (title/icon) from defaults so a rename in the
        // catalog flows through to existing users.
        for (SCIActionConfigSection *s in loaded) {
            for (SCIActionConfigSection *def in defaultSections) {
                if ([def.identifier isEqualToString:s.identifier]) {
                    if (!s.title.length) s.title = def.title;
                    if (!s.iconSF.length) s.iconSF = def.iconSF;
                    break;
                }
            }
        }
    }
    _sectionsStorage = loaded;

    // Disabled set
    NSMutableSet *disabled = [NSMutableSet set];
    if (hasStored) {
        NSArray *raw = dict[kCfgDisabled];
        if ([raw isKindOfClass:[NSArray class]]) {
            for (id v in raw) if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) [disabled addObject:v];
        }
    }

    // Fresh install: seed disabledByDefault descriptors. Stored config wins after.
    if (!hasStored) {
        for (SCIActionDescriptor *desc in [SCIActionCatalog descriptorsForSource:_source]) {
            if (desc.disabledByDefault) [disabled addObject:desc.identifier];
        }
    }
    _disabledStorage = disabled;

    // Show date
    if (hasStored && dict[kCfgShowDate]) {
        _showDate = [dict[kCfgShowDate] boolValue];
    } else {
        NSString *legacy = [SCIActionCatalog legacyDateTogglePrefKeyForSource:_source];
        _showDate = legacy.length ? [SCIUtils getBoolPref:legacy] : NO;
    }

    // Default tap
    if (hasStored && [dict[kCfgDefaultTap] isKindOfClass:[NSString class]] && [dict[kCfgDefaultTap] length]) {
        _defaultTap = [dict[kCfgDefaultTap] copy];
    } else {
        NSString *legacy = [SCIActionCatalog legacyDefaultTapPrefKeyForSource:_source];
        NSString *legacyVal = legacy.length ? [SCIUtils getStringPref:legacy] : nil;
        _defaultTap = legacyVal.length ? [legacyVal copy] : @"menu";
    }

    // Default copy info (profile only)
    if ([dict[kCfgDefaultCopy] isKindOfClass:[NSString class]] && [dict[kCfgDefaultCopy] length]) {
        _defaultCopyInfo = [dict[kCfgDefaultCopy] copy];
    } else {
        _defaultCopyInfo = SCIAID_CopyUsername;
    }

    [self normalize];
}

// MARK: - Normalize

// Every catalog action ends up in exactly one section. Unknown IDs dropped,
// new catalog actions appended to their default section (or last as fallback).
- (void)normalize {
    NSArray<SCIActionDescriptor *> *catalog = [SCIActionCatalog descriptorsForSource:_source];
    NSArray<SCIActionConfigSection *> *defaults = [SCIActionCatalog defaultSectionsForSource:_source];

    NSMutableSet<NSString *> *known = [NSMutableSet set];
    for (SCIActionDescriptor *d in catalog) [known addObject:d.identifier];

    // 1. Remove unknown action IDs from sections + disabled set.
    for (SCIActionConfigSection *s in _sectionsStorage) {
        NSMutableArray *kept = [NSMutableArray arrayWithCapacity:s.actionIDs.count];
        for (NSString *aid in s.actionIDs) if ([known containsObject:aid]) [kept addObject:aid];
        s.actionIDs = kept;
    }
    NSMutableSet *cleanedDisabled = [NSMutableSet set];
    for (NSString *aid in _disabledStorage) if ([known containsObject:aid]) [cleanedDisabled addObject:aid];
    _disabledStorage = cleanedDisabled;

    // 2. Drop empty sections that aren't in the default layout (keep default sections
    // even when emptied so reset feels familiar).
    NSMutableSet *defaultSectionIDs = [NSMutableSet set];
    for (SCIActionConfigSection *s in defaults) [defaultSectionIDs addObject:s.identifier];
    NSMutableArray *kept = [NSMutableArray array];
    for (SCIActionConfigSection *s in _sectionsStorage) {
        if (s.actionIDs.count > 0 || [defaultSectionIDs containsObject:s.identifier]) [kept addObject:s];
    }
    _sectionsStorage = kept;

    // 3. Add any default sections missing from the saved config (preserve order — append at end).
    for (SCIActionConfigSection *def in defaults) {
        BOOL found = NO;
        for (SCIActionConfigSection *s in _sectionsStorage) {
            if ([s.identifier isEqualToString:def.identifier]) { found = YES; break; }
        }
        if (!found) [_sectionsStorage addObject:[def copy]];
    }

    // 4. Find action IDs present in the catalog but not assigned to any section. Append
    //    each to its default section (or, if that section is missing, to the last section).
    NSMutableSet *assigned = [NSMutableSet set];
    for (SCIActionConfigSection *s in _sectionsStorage) [assigned addObjectsFromArray:s.actionIDs];

    for (NSString *aid in known) {
        if ([assigned containsObject:aid]) continue;

        NSString *targetSectionID = nil;
        for (SCIActionConfigSection *def in defaults) {
            if ([def.actionIDs containsObject:aid]) { targetSectionID = def.identifier; break; }
        }
        SCIActionConfigSection *target = nil;
        if (targetSectionID) target = [self sectionWithID:targetSectionID];
        if (!target) target = _sectionsStorage.lastObject;
        if (!target) continue;
        [target.actionIDs addObject:aid];
        [assigned addObject:aid];
    }
}

// MARK: - Properties

- (NSArray<SCIActionConfigSection *> *)sections { return [_sectionsStorage copy]; }
- (NSSet<NSString *> *)disabled { return [_disabledStorage copy]; }
- (NSArray<SCIActionConfigSection *> *)mutableSections { return _sectionsStorage; }

// MARK: - Lookup

- (SCIActionConfigSection *)sectionWithID:(NSString *)identifier {
    if (!identifier.length) return nil;
    for (SCIActionConfigSection *s in _sectionsStorage) {
        if ([s.identifier isEqualToString:identifier]) return s;
    }
    return nil;
}

- (SCIActionConfigSection *)sectionContainingActionID:(NSString *)actionID {
    if (!actionID.length) return nil;
    for (SCIActionConfigSection *s in _sectionsStorage) {
        if ([s.actionIDs containsObject:actionID]) return s;
    }
    return nil;
}

- (NSArray<NSString *> *)assignedActionIDs {
    NSMutableArray *out = [NSMutableArray array];
    for (SCIActionConfigSection *s in _sectionsStorage) [out addObjectsFromArray:s.actionIDs];
    return out;
}

- (BOOL)isActionDisabled:(NSString *)actionID {
    return actionID.length && [_disabledStorage containsObject:actionID];
}

- (void)setAction:(NSString *)actionID disabled:(BOOL)disabled {
    if (!actionID.length) return;
    if (disabled) [_disabledStorage addObject:actionID];
    else [_disabledStorage removeObject:actionID];
}

// MARK: - Mutation

- (void)moveSectionFromIndex:(NSInteger)src toIndex:(NSInteger)dst {
    if (src < 0 || src >= (NSInteger)_sectionsStorage.count) return;
    if (dst < 0) dst = 0;
    if (dst >= (NSInteger)_sectionsStorage.count) dst = _sectionsStorage.count - 1;
    if (src == dst) return;
    SCIActionConfigSection *moved = _sectionsStorage[src];
    [_sectionsStorage removeObjectAtIndex:src];
    [_sectionsStorage insertObject:moved atIndex:dst];
}

- (void)moveActionInSection:(SCIActionConfigSection *)section fromIndex:(NSInteger)src toIndex:(NSInteger)dst {
    if (!section) return;
    if (src < 0 || src >= (NSInteger)section.actionIDs.count) return;
    if (dst < 0) dst = 0;
    if (dst >= (NSInteger)section.actionIDs.count) dst = section.actionIDs.count - 1;
    if (src == dst) return;
    NSString *aid = section.actionIDs[src];
    [section.actionIDs removeObjectAtIndex:src];
    [section.actionIDs insertObject:aid atIndex:dst];
}

- (void)moveActionID:(NSString *)actionID toSection:(SCIActionConfigSection *)dstSection index:(NSInteger)dstIndex {
    if (!actionID.length || !dstSection) return;
    SCIActionConfigSection *fromSection = [self sectionContainingActionID:actionID];
    if (!fromSection) return;
    [fromSection.actionIDs removeObject:actionID];
    if (dstIndex < 0) dstIndex = 0;
    if (dstIndex > (NSInteger)dstSection.actionIDs.count) dstIndex = dstSection.actionIDs.count;
    [dstSection.actionIDs insertObject:actionID atIndex:dstIndex];
}

- (void)setSection:(SCIActionConfigSection *)section collapsible:(BOOL)collapsible {
    if (!section) return;
    section.collapsible = collapsible;
}

// MARK: - Save / Reset

- (void)save {
    NSMutableArray *secs = [NSMutableArray arrayWithCapacity:_sectionsStorage.count];
    for (SCIActionConfigSection *s in _sectionsStorage) [secs addObject:[s dictionaryRepresentation]];
    NSDictionary *dict = @{
        kCfgVersion: @(kCfgCurrentVer),
        kCfgSections: secs,
        kCfgDisabled: [_disabledStorage allObjects] ?: @[],
        kCfgShowDate: @(_showDate),
        kCfgDefaultTap: _defaultTap.length ? _defaultTap : @"menu",
        kCfgDefaultCopy: _defaultCopyInfo.length ? _defaultCopyInfo : SCIAID_CopyUsername,
    };
    [SCIUtils setPref:dict forKey:[SCIActionCatalog prefKeyForSource:_source]];
    // Keep legacy keys mirrored for back-compat with code paths still reading them.
    NSString *legacyDate = [SCIActionCatalog legacyDateTogglePrefKeyForSource:_source];
    if (legacyDate) [SCIUtils setPref:@(_showDate) forKey:legacyDate];
    NSString *legacyTap = [SCIActionCatalog legacyDefaultTapPrefKeyForSource:_source];
    if (legacyTap) [SCIUtils setPref:(_defaultTap.length ? _defaultTap : @"menu") forKey:legacyTap];

    [[NSNotificationCenter defaultCenter] postNotificationName:SCIActionMenuConfigDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"source": @(_source)}];
}

- (void)resetToDefaults {
    _sectionsStorage = [NSMutableArray array];
    for (SCIActionConfigSection *s in [SCIActionCatalog defaultSectionsForSource:_source]) {
        [_sectionsStorage addObject:[s copy]];
    }
    [_disabledStorage removeAllObjects];
    _showDate = NO;
    _defaultTap = @"menu";
    _defaultCopyInfo = SCIAID_CopyUsername;
    [self save];
}

@end
