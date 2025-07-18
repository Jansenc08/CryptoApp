//
//  CoinCell.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import <Foundation/Foundation.h>
#import "CoinCell.h"
#import "GFBodyLabel.h"
#import "CryptoApp-Swift.h" // Import the Swift classes
// This class defines method bodies and implementation logic 

@implementation CoinCell

// Returns the identifer for registering and dequeuing the cell
+ (NSString *)reuseID {
    return @"CoinCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self configureUI];
    }
    return self;
}

- (void)configureUI {
    // Init labels and views
    self.rankLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:9 weight:UIFontWeightMedium];
    self.coinImageView = [[CoinImageView alloc] init];
    self.nameLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:12 weight:UIFontWeightSemibold];
    self.marketSupply = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:10 weight:UIFontWeightMedium];
    self.priceLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:12 weight:UIFontWeightMedium];
    self.percentChangeLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:12 weight:UIFontWeightMedium];
    self.sparklineView = [[SparklineView alloc] init];

    // Init vertical left stack (rank, image, name/market info)
    UIStackView *nameStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.nameLabel, self.marketSupply]];
    nameStack.axis = UILayoutConstraintAxisVertical;
    nameStack.spacing = 2;
    nameStack.alignment = UIStackViewAlignmentLeading;

    self.leftStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.rankLabel, self.coinImageView, nameStack]];
    self.leftStack.axis = UILayoutConstraintAxisHorizontal;
    self.leftStack.alignment = UIStackViewAlignmentCenter;
    self.leftStack.spacing = 12;
    self.leftStack.distribution = UIStackViewDistributionFill;
    
    // Create sparkline and percentage stack (sparkline above percentage)
    UIStackView *sparklineAndPercentStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.sparklineView, self.percentChangeLabel]];
    sparklineAndPercentStack.axis = UILayoutConstraintAxisVertical;
    sparklineAndPercentStack.spacing = 4;
    sparklineAndPercentStack.alignment = UIStackViewAlignmentCenter;
    
    // Create right stack with price and sparkline/percent stack
    self.rightStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.priceLabel, sparklineAndPercentStack]];
    self.rightStack.axis = UILayoutConstraintAxisHorizontal;
    self.rightStack.alignment = UIStackViewAlignmentCenter;
    self.rightStack.spacing = 16; // Good spacing between price and sparkline/percent
    self.rightStack.distribution = UIStackViewDistributionFill;
    
    // Main horizontal layout with better spacing
    self.mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.leftStack, self.rightStack]];
    self.mainStack.axis = UILayoutConstraintAxisHorizontal;
    self.mainStack.alignment = UIStackViewAlignmentCenter;
    self.mainStack.distribution = UIStackViewDistributionFillProportionally; // Better distribution
    self.mainStack.spacing = 16;
    self.mainStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:self.mainStack];

    // Constraints for better spacing
    [NSLayoutConstraint activateConstraints:@[
        [self.mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

        // Fixed sizes for consistent layout
        [self.coinImageView.widthAnchor constraintEqualToConstant:32],
        [self.coinImageView.heightAnchor constraintEqualToConstant:32],
        [self.sparklineView.widthAnchor constraintEqualToConstant:60],
        [self.sparklineView.heightAnchor constraintEqualToConstant:20],
        
        // Minimum widths for better layout
        [self.rankLabel.widthAnchor constraintGreaterThanOrEqualToConstant:20],
        [self.nameLabel.widthAnchor constraintGreaterThanOrEqualToConstant:80],
        [self.priceLabel.widthAnchor constraintGreaterThanOrEqualToConstant:70],
        
        // Ensure sparkline and percent stack has proper width
        [sparklineAndPercentStack.widthAnchor constraintGreaterThanOrEqualToConstant:60],
    ]];
    
    // Set content hugging and compression resistance priorities for better layout
    [self.rankLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.coinImageView setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.sparklineView setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [sparklineAndPercentStack setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    
    // Allow name label to compress if needed, but keep price and percent change readable
    [self.nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.priceLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.percentChangeLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)configureWithRank:(NSInteger)rank
                     name:(NSString *)name
                    price:(NSString *)price
                   market:(NSString *)market
         percentChange24h:(NSString *)percentChange24h
             sparklineData:(NSArray<NSNumber *> *)sparklineData
            isPositiveChange:(BOOL)isPositiveChange {
    
    self.rankLabel.text = [NSString stringWithFormat:@"%ld", (long)rank];
    self.nameLabel.text = name;
    self.priceLabel.text = price;
    self.marketSupply.text = market;
    self.percentChangeLabel.text = percentChange24h;
    
    // Set percentage change color based on positive/negative change
    if (isPositiveChange) {
        self.percentChangeLabel.textColor = [UIColor systemGreenColor];
    } else {
        self.percentChangeLabel.textColor = [UIColor systemRedColor];
    }
    
    // Convert NSArray<NSNumber *> to array of doubles for Swift
    NSMutableArray<NSNumber *> *doubleArray = [NSMutableArray array];
    for (NSNumber *number in sparklineData) {
        [doubleArray addObject:number];
    }
    
    // Configure sparkline view
    [self.sparklineView configureWith:doubleArray isPositive:isPositiveChange];
}

- (void)updatePriceDataWithPrice:(NSString *)price
              percentChange24h:(NSString *)percentChange24h
                 sparklineData:(NSArray<NSNumber *> *)sparklineData
             isPositiveChange:(BOOL)isPositiveChange {
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return; // Cell was deallocated - skip update
        
        strongSelf.priceLabel.text = price;
        strongSelf.percentChangeLabel.text = percentChange24h;
        strongSelf.percentChangeLabel.textColor = isPositiveChange ? [UIColor systemGreenColor] : [UIColor systemRedColor];
        [strongSelf.sparklineView configureWith:sparklineData isPositive:isPositiveChange];
    });
}


// Resets the image when cells are reused by the collection view.
// Avoids image flickering / wrong images showing
- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coinImageView setPlaceholder];
}

@end
