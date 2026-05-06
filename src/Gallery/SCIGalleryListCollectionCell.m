#import "SCIGalleryListCollectionCell.h"
#import "SCIGalleryFile.h"
#import "SCIAssetUtils.h"
#import "../Utils.h"
#import "SCIGalleryShim.h"

// Fixed row height. With UICollectionViewCompositionalLayout's list section
// the cell self-sizes via auto-layout; we pin contentView height so the row
// has a stable size even though no flow-layout sizeForItemAtIndexPath fires.
static CGFloat const kSCIGalleryListRowHeight = 88.0;

@interface SCIGalleryListCollectionCell ()

@property (nonatomic, strong) SCIGalleryFile *file;

@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIImageView *rowTypeIcon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *technicalLabel;
@property (nonatomic, strong) UIView *pillBackground;
@property (nonatomic, strong) UILabel *pillLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *favoriteIcon;
@property (nonatomic, strong) UIButton *moreButton;
@property (nonatomic, strong) UIImageView *selectionIndicator;
@property (nonatomic, strong) NSLayoutConstraint *thumbnailLeadingConstraint;

@end

@implementation SCIGalleryListCollectionCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Cell must clip so contentView's leftward translation doesn't bleed
        // into adjacent cells when revealing the trailing delete action.
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.contentView.backgroundColor = [UIColor clearColor];

    self.thumbnailView = [[UIImageView alloc] init];
    self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    self.thumbnailView.clipsToBounds = YES;
    self.thumbnailView.layer.cornerRadius = 6;
    self.thumbnailView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.contentView addSubview:self.thumbnailView];

    self.rowTypeIcon = [[UIImageView alloc] init];
    self.rowTypeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.rowTypeIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.rowTypeIcon.tintColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:self.rowTypeIcon];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.titleLabel];

    self.technicalLabel = [[UILabel alloc] init];
    self.technicalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.technicalLabel.font = [UIFont systemFontOfSize:12];
    self.technicalLabel.textColor = [UIColor secondaryLabelColor];
    self.technicalLabel.numberOfLines = 1;
    self.technicalLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.technicalLabel];

    self.pillBackground = [[UIView alloc] init];
    self.pillBackground.translatesAutoresizingMaskIntoConstraints = NO;
    self.pillBackground.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    self.pillBackground.layer.cornerRadius = 5;
    self.pillBackground.clipsToBounds = YES;
    [self.contentView addSubview:self.pillBackground];

    self.pillLabel = [[UILabel alloc] init];
    self.pillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.pillLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.pillLabel.textColor = [UIColor secondaryLabelColor];
    self.pillLabel.numberOfLines = 1;
    [self.pillBackground addSubview:self.pillLabel];

    self.dateLabel = [[UILabel alloc] init];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.font = [UIFont systemFontOfSize:11];
    self.dateLabel.textColor = [UIColor tertiaryLabelColor];
    self.dateLabel.numberOfLines = 1;
    self.dateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.dateLabel];

    UIImage *favImg = [SCIAssetUtils instagramIconNamed:@"heart_filled" pointSize:14.0];
    self.favoriteIcon = [[UIImageView alloc] initWithImage:favImg];
    self.favoriteIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.favoriteIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteIcon.tintColor = [SCIUtils SCIColor_InstagramFavorite];
    self.favoriteIcon.hidden = YES;
    [self.contentView addSubview:self.favoriteIcon];

    self.selectionIndicator = [[UIImageView alloc] init];
    self.selectionIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionIndicator.contentMode = UIViewContentModeScaleAspectFit;
    self.selectionIndicator.tintColor = [UIColor secondaryLabelColor];
    self.selectionIndicator.hidden = YES;
    [self.contentView addSubview:self.selectionIndicator];

    UIImage *moreImg = [SCIAssetUtils instagramIconNamed:@"more" pointSize:22.0];
    self.moreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.moreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.moreButton setImage:moreImg forState:UIControlStateNormal];
    self.moreButton.tintColor = [UIColor secondaryLabelColor];
    self.moreButton.accessibilityLabel = SCILocalized(@"More");
    self.moreButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.moreButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [self.contentView addSubview:self.moreButton];

    UILayoutGuide *margin = self.contentView.layoutMarginsGuide;
    self.thumbnailLeadingConstraint = [self.thumbnailView.leadingAnchor constraintEqualToAnchor:margin.leadingAnchor constant:8];

    // Pin a fixed row height. Compositional layout self-sizes via auto-layout
    // (sizeForItemAtIndexPath isn't queried), so the contentView must be able
    // to derive its own height.
    NSLayoutConstraint *heightC = [self.contentView.heightAnchor constraintEqualToConstant:kSCIGalleryListRowHeight];
    heightC.priority = UILayoutPriorityRequired - 1;

    [NSLayoutConstraint activateConstraints:@[
        heightC,
        [self.selectionIndicator.leadingAnchor constraintEqualToAnchor:margin.leadingAnchor constant:8],
        [self.selectionIndicator.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.selectionIndicator.widthAnchor constraintEqualToConstant:20],
        [self.selectionIndicator.heightAnchor constraintEqualToConstant:20],

        self.thumbnailLeadingConstraint,
        [self.thumbnailView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.thumbnailView.widthAnchor constraintEqualToConstant:56],
        [self.thumbnailView.heightAnchor constraintEqualToConstant:56],

        [self.moreButton.trailingAnchor constraintEqualToAnchor:margin.trailingAnchor constant:-2],
        [self.moreButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.moreButton.widthAnchor constraintEqualToConstant:40],
        [self.moreButton.heightAnchor constraintEqualToConstant:40],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.thumbnailView.topAnchor constant:-1],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.favoriteIcon.leadingAnchor constant:-4],

        [self.rowTypeIcon.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.rowTypeIcon.centerYAnchor constraintEqualToAnchor:self.technicalLabel.centerYAnchor],
        [self.rowTypeIcon.widthAnchor constraintEqualToConstant:14],
        [self.rowTypeIcon.heightAnchor constraintEqualToConstant:14],

        [self.technicalLabel.leadingAnchor constraintEqualToAnchor:self.rowTypeIcon.trailingAnchor constant:4],
        [self.technicalLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3],
        [self.technicalLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.moreButton.leadingAnchor constant:-8],

        [self.pillBackground.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.pillBackground.topAnchor constraintEqualToAnchor:self.technicalLabel.bottomAnchor constant:4],
        [self.pillLabel.leadingAnchor constraintEqualToAnchor:self.pillBackground.leadingAnchor constant:8],
        [self.pillLabel.trailingAnchor constraintEqualToAnchor:self.pillBackground.trailingAnchor constant:-8],
        [self.pillLabel.topAnchor constraintEqualToAnchor:self.pillBackground.topAnchor constant:3],
        [self.pillLabel.bottomAnchor constraintEqualToAnchor:self.pillBackground.bottomAnchor constant:-3],

        [self.dateLabel.leadingAnchor constraintEqualToAnchor:self.pillBackground.trailingAnchor constant:8],
        [self.dateLabel.centerYAnchor constraintEqualToAnchor:self.pillBackground.centerYAnchor],
        [self.dateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.moreButton.leadingAnchor constant:-8],

        [self.favoriteIcon.trailingAnchor constraintEqualToAnchor:self.moreButton.leadingAnchor constant:-6],
        [self.favoriteIcon.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.favoriteIcon.widthAnchor constraintEqualToConstant:14],
        [self.favoriteIcon.heightAnchor constraintEqualToConstant:14],
    ]];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumbnailView.image = nil;
    self.titleLabel.text = nil;
    self.technicalLabel.text = nil;
    self.pillLabel.text = nil;
    self.dateLabel.text = nil;
    self.favoriteIcon.hidden = YES;
    self.file = nil;
    self.moreButton.menu = nil;
    self.moreButton.showsMenuAsPrimaryAction = NO;
    self.selectionIndicator.hidden = YES;
    self.selectionIndicator.image = nil;
    self.selectionIndicator.alpha = 0.0;
    self.thumbnailLeadingConstraint.constant = 8;
    self.moreButton.hidden = NO;
    self.moreButton.alpha = 1.0;
    self.onLeftSwipe = nil;
}

- (UIImage *)selectionIndicatorImageSelected:(BOOL)selected {
    NSString *resourceName = selected ? @"circle_check_filled" : @"circle";
    return [SCIAssetUtils instagramIconNamed:resourceName pointSize:20.0];
}

- (void)configureWithGalleryFile:(SCIGalleryFile *)file
                 selectionMode:(BOOL)selectionMode
                      selected:(BOOL)selected {
    self.file = file;
    self.titleLabel.text = [file listPrimaryTitle];
    self.technicalLabel.text = [file listTechnicalLine];
    self.pillLabel.text = [file shortSourceLabel];
    self.dateLabel.text = [file listDownloadDateString];

    UIImage *rowIcon = nil;
    switch (file.mediaType) {
        case SCIGalleryMediaTypeVideo:
            rowIcon = [SCIAssetUtils instagramIconNamed:@"video_filled" pointSize:12];
            break;
        case SCIGalleryMediaTypeAudio:
            rowIcon = [UIImage systemImageNamed:@"waveform"
                              withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]];
            break;
        case SCIGalleryMediaTypeGIF:
            rowIcon = [UIImage systemImageNamed:@"sparkles"
                              withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]];
            break;
        case SCIGalleryMediaTypeImage:
        default:
            rowIcon = [SCIAssetUtils instagramIconNamed:@"photo_filled" pointSize:12];
            break;
    }
    self.rowTypeIcon.image = rowIcon;

    self.favoriteIcon.hidden = !file.isFavorite;

    [self setSelectionMode:selectionMode selected:selected animated:NO];

    UIImage *thumb = [SCIGalleryFile loadThumbnailForFile:file];
    if (thumb) {
        self.thumbnailView.image = thumb;
    } else {
        __weak typeof(self) weakSelf = self;
        [SCIGalleryFile generateThumbnailForFile:file completion:^(BOOL ok) {
            if (!ok) return;
            if (weakSelf.file != file) return;
            UIImage *img = [SCIGalleryFile loadThumbnailForFile:file];
            if (img) weakSelf.thumbnailView.image = img;
        }];
    }
}

- (void)setSelectionMode:(BOOL)selectionMode selected:(BOOL)selected animated:(BOOL)animated {
    self.selectionIndicator.image = selectionMode ? [self selectionIndicatorImageSelected:selected] : nil;
    if (selectionMode) {
        self.selectionIndicator.hidden = NO;
    }
    if (!selectionMode) {
        self.moreButton.hidden = NO;
    }

    self.thumbnailLeadingConstraint.constant = selectionMode ? 40.0 : 8.0;

    void (^applyState)(void) = ^{
        self.selectionIndicator.alpha = selectionMode ? 1.0 : 0.0;
        self.moreButton.alpha = selectionMode ? 0.0 : 1.0;
        [self.contentView layoutIfNeeded];
    };
    void (^finishState)(void) = ^{
        self.selectionIndicator.hidden = !selectionMode;
        self.moreButton.hidden = selectionMode;
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:applyState
                         completion:^(__unused BOOL finished) {
            finishState();
        }];
    } else {
        applyState();
        finishState();
    }
}

- (void)setMoreActionsMenu:(UIMenu *)menu {
    self.moreButton.menu = menu;
    self.moreButton.showsMenuAsPrimaryAction = (menu != nil);
}

@end
