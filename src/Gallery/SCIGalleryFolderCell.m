#import "SCIGalleryFolderCell.h"
#import "../Utils.h"
#import "SCIGalleryShim.h"

@interface SCIGalleryFolderCell ()

@property (nonatomic, strong) UIView *listSeparator;
@property (nonatomic, strong) UIStackView *listStack;
@property (nonatomic, strong) UIImageView *listIcon;
@property (nonatomic, strong) UILabel *listTitle;
@property (nonatomic, strong) UILabel *listSubtitle;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIImageView *listChevron;

@end

@implementation SCIGalleryFolderCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.contentView.clipsToBounds = YES;
        self.contentView.layer.cornerRadius = 0;
        self.contentView.layer.borderWidth = 0;
        self.contentView.backgroundColor = [UIColor clearColor];

        UIImageSymbolConfiguration *folderConfig = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightRegular];
        _listIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"folder.fill" withConfiguration:folderConfig]];
        _listIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _listIcon.tintColor = [UIColor secondaryLabelColor];
        _listIcon.contentMode = UIViewContentModeScaleAspectFit;

        _listTitle = [[UILabel alloc] init];
        _listTitle.translatesAutoresizingMaskIntoConstraints = NO;
        _listTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _listTitle.textColor = [UIColor labelColor];
        _listTitle.numberOfLines = 1;
        _listTitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [_listTitle setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_listTitle setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

        _listSubtitle = [[UILabel alloc] init];
        _listSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
        _listSubtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _listSubtitle.textColor = [UIColor secondaryLabelColor];
        _listSubtitle.numberOfLines = 1;
        _listSubtitle.lineBreakMode = NSLineBreakByTruncatingTail;

        _textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_listTitle, _listSubtitle]];
        _textStack.translatesAutoresizingMaskIntoConstraints = NO;
        _textStack.axis = UILayoutConstraintAxisVertical;
        _textStack.alignment = UIStackViewAlignmentFill;
        _textStack.spacing = 2.0;
        [_textStack setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_textStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

        UIImageSymbolConfiguration *chevCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
        _listChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:chevCfg]];
        _listChevron.translatesAutoresizingMaskIntoConstraints = NO;
        _listChevron.tintColor = [UIColor tertiaryLabelColor];
        _listChevron.contentMode = UIViewContentModeScaleAspectFit;
        [_listChevron setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_listChevron setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

        _listStack = [[UIStackView alloc] initWithArrangedSubviews:@[_listIcon, _textStack, _listChevron]];
        _listStack.translatesAutoresizingMaskIntoConstraints = NO;
        _listStack.axis = UILayoutConstraintAxisHorizontal;
        _listStack.alignment = UIStackViewAlignmentCenter;
        _listStack.spacing = 12;
        _listStack.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 12);
        _listStack.layoutMarginsRelativeArrangement = YES;
        [_listStack setCustomSpacing:4 afterView:_textStack];
        [self.contentView addSubview:_listStack];

        UIView *sep = [[UIView alloc] init];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        sep.backgroundColor = [UIColor separatorColor];
        [self.contentView addSubview:sep];
        _listSeparator = sep;

        [NSLayoutConstraint activateConstraints:@[
            [_listStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_listStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_listStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_listStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_listIcon.widthAnchor constraintEqualToConstant:32],
            [_listIcon.heightAnchor constraintEqualToConstant:32],
            [_listChevron.widthAnchor constraintEqualToConstant:12],
            [_listChevron.heightAnchor constraintEqualToConstant:12],

            [sep.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:60],
            [sep.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [sep.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [sep.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _listTitle.text = nil;
    _listSubtitle.text = nil;
    _listSeparator.hidden = NO;
}

- (void)configureWithFolderName:(NSString *)name itemCount:(NSInteger)itemCount {
    _listTitle.text = name;
    _listSubtitle.text = [NSString stringWithFormat:@"%ld item%@", (long)itemCount, itemCount == 1 ? @"" : @"s"];
}

@end
