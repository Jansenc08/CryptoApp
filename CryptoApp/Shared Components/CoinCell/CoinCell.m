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

    // Init vertical left and right stacks
    UIStackView *nameStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.nameLabel, self.marketSupply]];
    nameStack.axis = UILayoutConstraintAxisVertical; //stacked top to bottom
    nameStack.spacing = 2;

    self.leftStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.rankLabel, self.coinImageView, nameStack]];
    self.leftStack.axis = UILayoutConstraintAxisHorizontal; // Stackview arranges subviews ina horizontal line (side by side)
    self.leftStack.alignment = UIStackViewAlignmentCenter; // Sets the alignment of views perpendicular to the axis.
    self.leftStack.spacing = 20;
    
    
    // Adjust pricelabel down
    // Wraps pricelabel in a vertical stack and pushes it down using a spacer
    UIView *spacer = [[UIView alloc] init];
    [spacer.heightAnchor constraintEqualToConstant:15].active = YES;

    UIStackView *priceWrapper = [[UIStackView alloc] initWithArrangedSubviews:@[spacer, self.priceLabel]];
    priceWrapper.axis = UILayoutConstraintAxisVertical;
    priceWrapper.spacing = 0;

    UIStackView *priceAndSparklineStack = [[UIStackView alloc] initWithArrangedSubviews:@[priceWrapper, self.sparklineView]];
    priceAndSparklineStack.axis = UILayoutConstraintAxisHorizontal;
    priceAndSparklineStack.alignment = UIStackViewAlignmentCenter;
    priceAndSparklineStack.spacing = 50;

    self.rightStack = [[UIStackView alloc] initWithArrangedSubviews:@[priceAndSparklineStack, self.percentChangeLabel]];
    self.rightStack.axis = UILayoutConstraintAxisVertical;
    self.rightStack.alignment = UIStackViewAlignmentTrailing;
    self.rightStack.spacing = 4;
    
    // Main horizontal layout
    self.mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.leftStack, self.rightStack]];
    self.mainStack.axis = UILayoutConstraintAxisHorizontal;
    self.mainStack.alignment = UIStackViewAlignmentCenter;
    self.mainStack.distribution = UIStackViewDistributionEqualSpacing;
    self.mainStack.spacing = 12;
    self.mainStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:self.mainStack]; // Then added to the cell

    // Constraints (Pins the mainStack to all sides of the cell with padding.)
    [NSLayoutConstraint activateConstraints:@[
        [self.mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],

        [self.coinImageView.widthAnchor constraintEqualToConstant:32],
        [self.coinImageView.heightAnchor constraintEqualToConstant:32],
        [self.sparklineView.widthAnchor constraintEqualToConstant:60],
        [self.sparklineView.heightAnchor constraintEqualToConstant:20],
    ]];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.priceLabel.text = price;
        self.percentChangeLabel.text = percentChange24h;
        self.percentChangeLabel.textColor = isPositiveChange ? [UIColor systemGreenColor] : [UIColor systemRedColor];
        [self.sparklineView configureWith:sparklineData isPositive:isPositiveChange];
    });
}


// Resets the image when cells are reused by the collection view.
// Avoids image flickering / wrong images showing
- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coinImageView setPlaceholder];
}

@end
