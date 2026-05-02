#import "SCIIconPicker.h"
#import "../ActionButton/SCIActionIcon.h"
#import "../Localization/SCILocalization.h"

static NSString *const kCellID = @"SCIIconCell";

#pragma mark - Cell

@interface SCIIconCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIImageView *checkBadge;
@end

@implementation SCIIconCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.contentView.layer.cornerRadius = 16;
    self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    self.contentView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.contentView.layer.borderColor = [UIColor separatorColor].CGColor;
    self.contentView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

    _iconView = [UIImageView new];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeCenter;
    _iconView.tintColor = [UIColor labelColor];
    [self.contentView addSubview:_iconView];

    UIImageSymbolConfiguration *checkCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold];
    _checkBadge = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:checkCfg]];
    _checkBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _checkBadge.tintColor = [UIColor systemBlueColor];
    _checkBadge.hidden = YES;
    // White pad fills the SF glyph cutout so it stays crisp on the tinted bg.
    _checkBadge.backgroundColor = [UIColor whiteColor];
    _checkBadge.layer.cornerRadius = 9;
    _checkBadge.layer.masksToBounds = YES;
    [self.contentView addSubview:_checkBadge];

    [NSLayoutConstraint activateConstraints:@[
        [_iconView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_checkBadge.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:6],
        [_checkBadge.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-6],
        [_checkBadge.widthAnchor    constraintEqualToConstant:18],
        [_checkBadge.heightAnchor   constraintEqualToConstant:18],
    ]];

    return self;
}

- (void)applySelected:(BOOL)selected {
    self.checkBadge.hidden = !selected;
    if (selected) {
        self.contentView.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.16];
        self.contentView.layer.borderColor = [UIColor systemBlueColor].CGColor;
        self.contentView.layer.borderWidth = 2.0;
        self.iconView.tintColor = [UIColor systemBlueColor];
    } else {
        self.contentView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        self.contentView.layer.borderColor = [UIColor separatorColor].CGColor;
        self.contentView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.iconView.tintColor = [UIColor labelColor];
    }
}

- (void)configureWithSymbolName:(NSString *)name selected:(BOOL)selected {
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:26
                                                         weight:UIImageSymbolWeightSemibold];
    self.iconView.image = [UIImage systemImageNamed:name withConfiguration:cfg];
    [self applySelected:selected];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self applySelected:NO];
}

@end


#pragma mark - VC

@interface SCIIconPickerViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSString *> *icons;
@end

@implementation SCIIconPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"Action button icon");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    // Drop any curated names the running iOS doesn't ship.
    NSMutableArray *valid = [NSMutableArray array];
    for (NSString *name in [SCIActionIcon availableSystemIcons]) {
        if ([UIImage systemImageNamed:name]) [valid addObject:name];
    }
    self.icons = valid;

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 24, 16);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                             collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[SCIIconCell class] forCellWithReuseIdentifier:kCellID];
    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.collectionView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
        [self.collectionView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSString *active = [SCIActionIcon symbolName];
    NSUInteger idx = [self.icons indexOfObject:active];
    if (idx != NSNotFound) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]
                                    atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                                            animated:NO];
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    CGFloat available = self.view.bounds.size.width - 32;
    NSInteger cols = MAX(4, (NSInteger)floor(available / 84.0));
    CGFloat side = floor((available - layout.minimumInteritemSpacing * (cols - 1)) / cols);
    layout.itemSize = CGSizeMake(side, side);
}

#pragma mark UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    return self.icons.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SCIIconCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:indexPath];
    NSString *name = self.icons[indexPath.item];
    [cell configureWithSymbolName:name selected:[name isEqualToString:[SCIActionIcon symbolName]]];
    return cell;
}

#pragma mark UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *picked = self.icons[indexPath.item];
    if ([picked isEqualToString:[SCIActionIcon symbolName]]) {
        [cv deselectItemAtIndexPath:indexPath animated:YES];
        return;
    }
    [SCIActionIcon setSymbolName:picked];
    [cv reloadData];

    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];
}

@end
