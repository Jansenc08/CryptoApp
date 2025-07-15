//
//  FilterButton.m
//  CryptoApp
//
//  Created by AI Assistant on 7/7/25.
//

#import "FilterButton.h"

@interface FilterButton()
@property (nonatomic, strong) UIImageView *arrowImageView;
@end

@implementation FilterButton

- (instancetype)initWithTitle:(NSString *)title {
    self = [super init];
    if (self) {
        [self setupAppearance];
        [self setupLabelsWithTitle:title];
        [self setupArrowIcon];
        [self setupConstraints];
        [self setupTouchHandling];
    }
    return self;
}

- (void)setupAppearance {
    // CoinMarketCap-style appearance
    self.backgroundColor = [UIColor systemBackgroundColor];
    self.layer.cornerRadius = 8.0;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor systemGray4Color].CGColor;
    
    // Shadow for depth
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 4.0;
    self.layer.shadowOpacity = 0.1;
}

- (void)setupLabelsWithTitle:(NSString *)title {
    // Title label
    self.customTitleLabel = [[UILabel alloc] init];
    self.customTitleLabel.text = title;
    self.customTitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.customTitleLabel.textColor = [UIColor labelColor];
    self.customTitleLabel.textAlignment = NSTextAlignmentLeft;
    self.customTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.customTitleLabel];
}

- (void)setupArrowIcon {
    self.arrowImageView = [[UIImageView alloc] init];
    UIImage *arrowImage = [UIImage systemImageNamed:@"chevron.down"];
    self.arrowImageView.image = arrowImage;
    self.arrowImageView.tintColor = [UIColor secondaryLabelColor];
    self.arrowImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.arrowImageView];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Title label constraints - center it vertically
        [self.customTitleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.customTitleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.customTitleLabel.trailingAnchor constraintEqualToAnchor:self.arrowImageView.leadingAnchor constant:-8],
        
        // Arrow image view constraints
        [self.arrowImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.arrowImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [self.arrowImageView.widthAnchor constraintEqualToConstant:16],
        [self.arrowImageView.heightAnchor constraintEqualToConstant:16],
        
        // Button height constraint
        [self.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)setupTouchHandling {
    [self addTarget:self action:@selector(touchDown:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(touchUp:) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(touchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(touchUp:) forControlEvents:UIControlEventTouchCancel];
}

- (void)touchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
        self.alpha = 0.8;
    }];
}

- (void)touchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }];
}

- (void)updateTitle:(NSString *)title {
    [UIView animateWithDuration:0.2 animations:^{
        self.customTitleLabel.text = title;
    }];
}

@end 
