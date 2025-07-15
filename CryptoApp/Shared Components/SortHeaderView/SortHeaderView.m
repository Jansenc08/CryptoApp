//
//  SortHeaderView.m
//  CryptoApp
//
//  Created by AI Assistant on 7/7/25.
//

#import "SortHeaderView.h"

@interface SortHeaderView()

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIButton *rankButton;
@property (nonatomic, strong) UIButton *marketCapButton;
@property (nonatomic, strong) UIButton *priceButton;
@property (nonatomic, strong) UIButton *priceChangeButton;
@property (nonatomic, strong) NSDictionary<NSNumber *, NSString *> *originalTitles;

@end

@implementation SortHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
        [self setupButtons];
        [self setupConstraints];
        
        // Default to Price column descending
        self.currentSortColumn = CryptoSortColumnPrice;
        self.currentSortOrder = CryptoSortOrderDescending;
        [self updateSortIndicators];
    }
    return self;
}

- (void)setupView {
    self.backgroundColor = [UIColor systemBackgroundColor];
    
    // Add subtle border bottom using CALayer
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0, 43.5, self.frame.size.width, 0.5);
    bottomBorder.backgroundColor = [UIColor systemGray4Color].CGColor;
    [self.layer addSublayer:bottomBorder];
    
    // Create horizontal stack view for columns
    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisHorizontal;
    self.stackView.distribution = UIStackViewDistributionFillEqually;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.spacing = 0;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.stackView];
}

- (void)setupButtons {
    // Rank column
    self.rankButton = [self createColumnButtonWithTitle:@"Rank" tag:CryptoSortColumnRank];
    [self.stackView addArrangedSubview:self.rankButton];
    
    // Market Cap column
    self.marketCapButton = [self createColumnButtonWithTitle:@"Market Cap" tag:CryptoSortColumnMarketCap];
    [self.stackView addArrangedSubview:self.marketCapButton];
    
    // Price column
    self.priceButton = [self createColumnButtonWithTitle:@"Price" tag:CryptoSortColumnPrice];
    [self.stackView addArrangedSubview:self.priceButton];
    
    // Price Change column (will be updated based on filter)
    self.priceChangeButton = [self createColumnButtonWithTitle:@"24h%" tag:CryptoSortColumnPriceChange];
    [self.stackView addArrangedSubview:self.priceChangeButton];
    
    // Store original titles for reference
    self.originalTitles = @{
        @(CryptoSortColumnRank): @"Rank",
        @(CryptoSortColumnMarketCap): @"Market Cap", 
        @(CryptoSortColumnPrice): @"Price",
        @(CryptoSortColumnPriceChange): @"24h%"
    };
}

- (UIButton *)createColumnButtonWithTitle:(NSString *)title tag:(NSInteger)tag {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = tag;
    
    // Configure title
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [button setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
    
    // Configure layout
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add action
    [button addTarget:self action:@selector(columnButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Add subtle hover effect
    [button addTarget:self action:@selector(columnButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(columnButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(columnButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(columnButtonTouchUp:) forControlEvents:UIControlEventTouchCancel];
    
    return button;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.stackView.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)columnButtonTapped:(UIButton *)sender {
    CryptoSortColumn column = (CryptoSortColumn)sender.tag;
    
    // If same column, toggle order; if different column, use descending
    if (self.currentSortColumn == column) {
        self.currentSortOrder = (self.currentSortOrder == CryptoSortOrderDescending) ? CryptoSortOrderAscending : CryptoSortOrderDescending;
    } else {
        self.currentSortColumn = column;
        self.currentSortOrder = CryptoSortOrderDescending; // Default to descending for new column
    }
    
    [self updateSortIndicators];
    
    // Notify delegate
    if (self.delegate && [self.delegate respondsToSelector:@selector(sortHeaderView:didSelect:with:)]) {
        [self.delegate sortHeaderView:self didSelect:column with:self.currentSortOrder];
    }
}

- (void)updateSortIndicators {
    NSArray<UIButton *> *buttons = @[self.rankButton, self.marketCapButton, self.priceButton, self.priceChangeButton];
    
    for (UIButton *button in buttons) {
        CryptoSortColumn column = (CryptoSortColumn)button.tag;
        NSString *originalTitle = self.originalTitles[@(column)];
        
        if (column == self.currentSortColumn) {
            // Active column - show sort indicator
            NSString *arrow = (self.currentSortOrder == CryptoSortOrderDescending) ? @"▼" : @"▲";
            NSString *titleWithArrow = [NSString stringWithFormat:@"%@ %@", originalTitle, arrow];
            [button setTitle:titleWithArrow forState:UIControlStateNormal];
            [button setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        } else {
            // Inactive column - show original title without arrow
            [button setTitle:originalTitle forState:UIControlStateNormal];
            [button setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
        }
    }
}

- (void)updatePriceChangeColumnTitle:(NSString *)title {
    // Update the original title in our dictionary
    NSMutableDictionary *mutableTitles = [self.originalTitles mutableCopy];
    mutableTitles[@(CryptoSortColumnPriceChange)] = title;
    self.originalTitles = [mutableTitles copy];
    
    // Refresh sort indicators to maintain current state with new title
    [self updateSortIndicators];
}

#pragma mark - Touch Effects

- (void)columnButtonTouchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.alpha = 0.6;
    }];
}

- (void)columnButtonTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.alpha = 1.0;
    }];
}

@end 