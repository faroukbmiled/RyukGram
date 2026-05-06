// SCIActionMenuConfig — per-source persisted menu layout. Backed by a single
// NSDictionary pref key per source (see SCIActionCatalog +prefKeyForSource:).
// On first load for a given source, seeds defaults from SCIActionCatalog and
// migrates legacy `<src>_action_default` / `menu_date_<src>` keys.

#import <Foundation/Foundation.h>
#import "SCIActionCatalog.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SCIActionMenuConfigDidChangeNotification; // userInfo: { @"source": @(src) }

@interface SCIActionMenuConfig : NSObject

@property (nonatomic, assign, readonly) SCIActionSource source;
@property (nonatomic, copy, readonly) NSArray<SCIActionConfigSection *> *sections;
@property (nonatomic, copy, readonly) NSSet<NSString *> *disabled;
@property (nonatomic, assign) BOOL showDate;
@property (nonatomic, copy) NSString *defaultTap;       // SCIAID_* or @"menu"
@property (nonatomic, copy) NSString *defaultCopyInfo;  // profile-only

+ (instancetype)configForSource:(SCIActionSource)source;
+ (void)reloadAll;

- (NSArray<SCIActionConfigSection *> *)mutableSections;
- (BOOL)isActionDisabled:(NSString *)actionID;
- (void)setAction:(NSString *)actionID disabled:(BOOL)disabled;

- (nullable SCIActionConfigSection *)sectionWithID:(NSString *)identifier;
- (nullable SCIActionConfigSection *)sectionContainingActionID:(NSString *)actionID;
- (NSArray<NSString *> *)assignedActionIDs;

- (void)moveSectionFromIndex:(NSInteger)src toIndex:(NSInteger)dst;
- (void)moveActionInSection:(SCIActionConfigSection *)section
                  fromIndex:(NSInteger)src
                    toIndex:(NSInteger)dst;
- (void)moveActionID:(NSString *)actionID
            toSection:(SCIActionConfigSection *)dstSection
                index:(NSInteger)dstIndex;
- (void)setSection:(SCIActionConfigSection *)section collapsible:(BOOL)collapsible;

- (void)save;
- (void)resetToDefaults;

@end

NS_ASSUME_NONNULL_END
