//
//  AddCoinCell.m
//  CryptoApp
//
//  Created by AI Assistant on 7/8/25.
//

#import "AddCoinCell.h"
#import "GFBodyLabel.h"

@implementation AddCoinCell

+ (NSString *)reuseID {
    return @"AddCoinCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self configureUI];
    }
    return self;
}

- (void)configureUI {
    // Cell styling
    self.backgroundColor = UIColor.systemBackgroundColor;
    self.layer.cornerRadius = 8;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0].CGColor;
    
    // Coin image view
    self.coinImageView = [[CoinImageView alloc] init];
    self.coinImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.coinImageView];
    
    // Symbol label
    self.symbolLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:16 weight:UIFontWeightSemibold];
    self.symbolLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.symbolLabel];
    
    // Name label
    self.nameLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:14 weight:UIFontWeightRegular];
    self.nameLabel.textColor = UIColor.secondaryLabelColor;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.nameLabel];
    
    // Selection overlay
    self.selectionOverlay = [[UIView alloc] init];
    self.selectionOverlay.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.1];
    self.selectionOverlay.layer.cornerRadius = 8;
    self.selectionOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionOverlay.hidden = YES;
    [self.contentView addSubview:self.selectionOverlay];
    
    // Checkmark image view
    self.checkmarkImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
    self.checkmarkImageView.tintColor = UIColor.systemBlueColor;
    self.checkmarkImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkmarkImageView.hidden = YES;
    [self.contentView addSubview:self.checkmarkImageView];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Selection overlay (covers entire cell)
        [self.selectionOverlay.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.selectionOverlay.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.selectionOverlay.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.selectionOverlay.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        // Coin image view
        [self.coinImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.coinImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.coinImageView.widthAnchor constraintEqualToConstant:40],
        [self.coinImageView.heightAnchor constraintEqualToConstant:40],
        
        // Symbol label
        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.coinImageView.trailingAnchor constant:12],
        [self.symbolLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.symbolLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.checkmarkImageView.leadingAnchor constant:-8],
        
        // Name label
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.coinImageView.trailingAnchor constant:12],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.symbolLabel.bottomAnchor constant:2],
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.checkmarkImageView.leadingAnchor constant:-8],
        [self.nameLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        // Checkmark image view
        [self.checkmarkImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.checkmarkImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.checkmarkImageView.widthAnchor constraintEqualToConstant:24],
        [self.checkmarkImageView.heightAnchor constraintEqualToConstant:24]
    ]];
    
    // Set content hugging priorities
    [self.symbolLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    [self.nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)configureWithSymbol:(NSString *)symbol
                       name:(NSString *)name
                   logoURL:(nullable NSString *)logoURL
                 isSelected:(BOOL)isSelected
              selectionType:(AddCoinSelectionType)selectionType {
    
    self.symbolLabel.text = symbol;
    self.nameLabel.text = name;
    self.selectionType = selectionType;
    
    // Load coin logo
    if (logoURL) {
        [self.coinImageView downloadImageFromURL:logoURL];
    } else {
        [self.coinImageView setPlaceholder];
    }
    
    // Set selection state
    [self setSelectedForWatchlist:isSelected selectionType:selectionType animated:NO];
}

- (void)setSelectedForWatchlist:(BOOL)selected 
                  selectionType:(AddCoinSelectionType)selectionType
                       animated:(BOOL)animated {
    _isSelectedForWatchlist = selected;
    _selectionType = selectionType;
    
    void (^updateUI)(void) = ^{
        self.selectionOverlay.hidden = !selected;
        self.checkmarkImageView.hidden = !selected;
        
        if (selected) {
            // Configure visual state based on selection type
            if (selectionType == AddCoinSelectionTypeRemove) {
                // Red styling for removal
                self.selectionOverlay.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.1];
                self.checkmarkImageView.image = [UIImage systemImageNamed:@"xmark.circle.fill"];
                self.checkmarkImageView.tintColor = UIColor.systemRedColor;
                self.layer.borderColor = UIColor.systemRedColor.CGColor;
            } else {
                // Blue styling for addition (default)
                self.selectionOverlay.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.1];
                self.checkmarkImageView.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
                self.checkmarkImageView.tintColor = UIColor.systemBlueColor;
                self.layer.borderColor = UIColor.systemBlueColor.CGColor;
            }
            self.layer.borderWidth = 2.0;
        } else {
            // Unselected state
            self.layer.borderColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0].CGColor;
            self.layer.borderWidth = 1.0;
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:updateUI];
    } else {
        updateUI();
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coinImageView cancelCurrentDownload];
    [self.coinImageView setPlaceholder];
    [self setSelectedForWatchlist:NO selectionType:AddCoinSelectionTypeAdd animated:NO];
}

@end 