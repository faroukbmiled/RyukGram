#import "SCIGallerySortViewController.h"
#import "SCIGalleryChip.h"
#import "../Utils.h"
#import "SCIGalleryShim.h"

@interface SCIGallerySortViewController ()
@property (nonatomic, strong) NSMutableArray<SCIGalleryChip *> *chips;
@end

@implementation SCIGallerySortViewController

+ (NSArray<NSSortDescriptor *> *)sortDescriptorsForMode:(SCIGallerySortMode)mode {
    switch (mode) {
        case SCIGallerySortModeDateAddedDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
        case SCIGallerySortModeDateAddedAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:YES]];
        case SCIGallerySortModeNameAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"relativePath" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
        case SCIGallerySortModeNameDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"relativePath" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)]];
        case SCIGallerySortModeSizeDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"fileSize" ascending:NO]];
        case SCIGallerySortModeSizeAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"fileSize" ascending:YES]];
        case SCIGallerySortModeTypeAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"mediaType" ascending:YES],
                     [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
        case SCIGallerySortModeTypeDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"mediaType" ascending:NO],
                     [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
    }
    return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
}

+ (NSString *)labelForMode:(SCIGallerySortMode)mode {
    switch (mode) {
        case SCIGallerySortModeDateAddedDesc: return SCILocalized(@"Newest first");
        case SCIGallerySortModeDateAddedAsc:  return SCILocalized(@"Oldest first");
        case SCIGallerySortModeNameAsc:       return SCILocalized(@"Name A-Z");
        case SCIGallerySortModeNameDesc:      return SCILocalized(@"Name Z-A");
        case SCIGallerySortModeSizeDesc:      return SCILocalized(@"Largest first");
        case SCIGallerySortModeSizeAsc:       return SCILocalized(@"Smallest first");
        case SCIGallerySortModeTypeAsc:       return SCILocalized(@"Images first");
        case SCIGallerySortModeTypeDesc:      return SCILocalized(@"Videos first");
    }
    return SCILocalized(@"Newest first");
}

+ (NSString *)symbolForMode:(SCIGallerySortMode)mode {
    switch (mode) {
        case SCIGallerySortModeDateAddedDesc: return @"calendar";
        case SCIGallerySortModeDateAddedAsc:  return @"calendar.badge.clock";
        case SCIGallerySortModeNameAsc:       return @"textformat";
        case SCIGallerySortModeNameDesc:      return @"textformat";
        case SCIGallerySortModeSizeDesc:      return @"arrow.up.square";
        case SCIGallerySortModeSizeAsc:       return @"arrow.down.square";
        case SCIGallerySortModeTypeAsc:       return @"photo";
        case SCIGallerySortModeTypeDesc:      return @"video";
    }
    return @"arrow.up.arrow.down";
}

- (instancetype)init {
    if ((self = [super init])) {
        _currentSortMode = SCIGallerySortModeDateAddedDesc;
        _chips = [NSMutableArray new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.sheetTitle = SCILocalized(@"Sort");
    [self buildContent];
}

// Sort needs less room than filter — 4 chip rows + title fit in a short card.
- (CGFloat)preferredCardHeight {
    CGFloat screen = UIScreen.mainScreen.bounds.size.height;
    return MAX(320.0, MIN(380.0, screen * 0.46));
}

// 2-column grid keeps the picker compact while letting each row's pair share
// equal width so the layout stays balanced.
- (void)buildContent {
    NSArray<NSArray<NSNumber *> *> *rows = @[
        @[@(SCIGallerySortModeDateAddedDesc), @(SCIGallerySortModeDateAddedAsc)],
        @[@(SCIGallerySortModeNameAsc),       @(SCIGallerySortModeNameDesc)],
        @[@(SCIGallerySortModeSizeDesc),      @(SCIGallerySortModeSizeAsc)],
        @[@(SCIGallerySortModeTypeAsc),       @(SCIGallerySortModeTypeDesc)],
    ];
    UIStackView *grid = [UIStackView new];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 8;
    for (NSArray<NSNumber *> *row in rows) {
        UIStackView *line = [UIStackView new];
        line.axis = UILayoutConstraintAxisHorizontal;
        line.spacing = 8;
        line.distribution = UIStackViewDistributionFillEqually;
        for (NSNumber *modeNum in row) {
            SCIGallerySortMode mode = (SCIGallerySortMode)modeNum.integerValue;
            SCIGalleryChip *chip = [SCIGalleryChip chipWithTitle:[SCIGallerySortViewController labelForMode:mode]
                                                           symbol:[SCIGallerySortViewController symbolForMode:mode]];
            chip.tag = mode;
            chip.onState = (mode == self.currentSortMode);
            [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
            [chip.heightAnchor constraintEqualToConstant:48].active = YES;
            [line addArrangedSubview:chip];
            [self.chips addObject:chip];
        }
        [grid addArrangedSubview:line];
    }
    [self addContentView:grid];
}

- (void)chipTapped:(SCIGalleryChip *)chip {
    SCIGallerySortMode mode = (SCIGallerySortMode)chip.tag;
    self.currentSortMode = mode;
    for (SCIGalleryChip *c in self.chips) [c setOnState:(c.tag == chip.tag) animated:YES];
    if ([self.delegate respondsToSelector:@selector(sortController:didSelectSortMode:)]) {
        [self.delegate sortController:self didSelectSortMode:mode];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismissAnimated];
    });
}

@end
