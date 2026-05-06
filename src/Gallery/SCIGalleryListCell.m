#import "SCIGalleryListCell.h"
#import "SCIGalleryFile.h"
#import "SCIAssetUtils.h"
#import "../Utils.h"
#import "SCIGalleryShim.h"

@interface SCIGalleryListCell ()

@property (nonatomic, strong, readwrite) SCIGalleryFile *file;

@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIImageView *typeIcon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIImageView *favoriteIcon;

@end

@implementation SCIGalleryListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    self.thumbnailView = [[UIImageView alloc] init];
    self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    self.thumbnailView.clipsToBounds = YES;
    self.thumbnailView.layer.cornerRadius = 6;
    self.thumbnailView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.contentView addSubview:self.thumbnailView];

    self.typeIcon = [[UIImageView alloc] init];
    self.typeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeIcon.image = [SCIAssetUtils instagramIconNamed:@"video_filled" pointSize:10.0];
    self.typeIcon.tintColor = [UIColor whiteColor];
    self.typeIcon.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    self.typeIcon.layer.cornerRadius = 9;
    self.typeIcon.contentMode = UIViewContentModeCenter;
    self.typeIcon.hidden = YES;
    [self.contentView addSubview:self.typeIcon];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.contentView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [UIFont systemFontOfSize:12];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.numberOfLines = 1;
    [self.contentView addSubview:self.subtitleLabel];

    self.detailLabel = [[UILabel alloc] init];
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailLabel.font = [UIFont systemFontOfSize:11];
    self.detailLabel.textColor = [UIColor tertiaryLabelColor];
    self.detailLabel.numberOfLines = 1;
    [self.contentView addSubview:self.detailLabel];

    UIImage *favImg = [SCIAssetUtils instagramIconNamed:@"heart_filled" pointSize:14.0];
    self.favoriteIcon = [[UIImageView alloc] initWithImage:favImg];
    self.favoriteIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.favoriteIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteIcon.tintColor = [SCIUtils SCIColor_InstagramFavorite];
    self.favoriteIcon.hidden = YES;
    [self.contentView addSubview:self.favoriteIcon];

    [NSLayoutConstraint activateConstraints:@[
        [self.thumbnailView.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [self.thumbnailView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.thumbnailView.widthAnchor constraintEqualToConstant:56],
        [self.thumbnailView.heightAnchor constraintEqualToConstant:56],
        [self.thumbnailView.topAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.thumbnailView.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-8],

        [self.typeIcon.leadingAnchor constraintEqualToAnchor:self.thumbnailView.leadingAnchor constant:4],
        [self.typeIcon.bottomAnchor constraintEqualToAnchor:self.thumbnailView.bottomAnchor constant:-4],
        [self.typeIcon.widthAnchor constraintEqualToConstant:18],
        [self.typeIcon.heightAnchor constraintEqualToConstant:18],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.thumbnailView.topAnchor constant:2],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.favoriteIcon.leadingAnchor constant:-4],

        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],

        [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.detailLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:2],
        [self.detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],

        [self.favoriteIcon.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
        [self.favoriteIcon.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.favoriteIcon.widthAnchor constraintEqualToConstant:14],
        [self.favoriteIcon.heightAnchor constraintEqualToConstant:14],
    ]];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumbnailView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.detailLabel.text = nil;
    self.typeIcon.hidden = YES;
    self.favoriteIcon.hidden = YES;
    self.file = nil;
}

- (void)configureWithGalleryFile:(SCIGalleryFile *)file {
    self.file = file;
    self.titleLabel.text = [file displayName];
    self.subtitleLabel.text = [file sourceLabel];
    self.detailLabel.text = [self formattedDetailForFile:file];

    BOOL isVideo = (file.mediaType == SCIGalleryMediaTypeVideo);
    BOOL isAudio = (file.mediaType == SCIGalleryMediaTypeAudio);
    BOOL isGIF = (file.mediaType == SCIGalleryMediaTypeGIF);
    if (isAudio) {
        self.typeIcon.hidden = NO;
        self.typeIcon.image = [UIImage systemImageNamed:@"waveform.circle.fill"];
    } else if (isGIF) {
        self.typeIcon.hidden = NO;
        self.typeIcon.image = [UIImage systemImageNamed:@"sparkles"];
    } else {
        self.typeIcon.hidden = !isVideo;
        if (isVideo) self.typeIcon.image = [UIImage systemImageNamed:@"video.fill"];
    }
    self.favoriteIcon.hidden = !file.isFavorite;

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

- (NSString *)formattedDetailForFile:(SCIGalleryFile *)file {
    NSString *size = [NSByteCountFormatter stringFromByteCount:file.fileSize
                                                   countStyle:NSByteCountFormatterCountStyleFile];

    static NSDateFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateStyle = NSDateFormatterShortStyle;
        fmt.timeStyle = NSDateFormatterShortStyle;
    });

    NSString *dateStr = file.dateAdded ? [fmt stringFromDate:file.dateAdded] : @"";
    if (size.length == 0) return dateStr;
    if (dateStr.length == 0) return size;
    return [NSString stringWithFormat:@"%@ • %@", size, dateStr];
}

@end
