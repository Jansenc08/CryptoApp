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
    self.rankLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:9 weight:UIFontWeightMedium];
    self.coinImageView = [[CoinImageView alloc] init];
    self.nameLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:12 weight:UIFontWeightSemibold];
    self.priceLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:12 weight:UIFontWeightMedium];
    self.sparklineView = [[SparklineView alloc] init];
    self.percentChangeLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:12 weight:UIFontWeightMedium];
    self.marketSupply = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:10 weight:UIFontWeightMedium];

    [self.contentView addSubview:self.rankLabel];
    [self.contentView addSubview:self.coinImageView];
    [self.contentView addSubview:self.nameLabel];
    [self.contentView addSubview:self.priceLabel];
    [self.contentView addSubview:self.marketSupply];
    [self.contentView addSubview:self.sparklineView];
    [self.contentView addSubview:self.percentChangeLabel];

    // Set translatesAutoresizingMaskIntoConstraints to NO for all views
    self.rankLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.coinImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.marketSupply.translatesAutoresizingMaskIntoConstraints = NO;
    self.sparklineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.percentChangeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    [NSLayoutConstraint activateConstraints:@[
        // Rank label
        [self.rankLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.rankLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        
        // Coin image next to rank
        [self.coinImageView.leadingAnchor constraintEqualToAnchor:self.rankLabel.trailingAnchor constant:8],
        [self.coinImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.coinImageView.widthAnchor constraintEqualToConstant:32],
        [self.coinImageView.heightAnchor constraintEqualToConstant:32],
        
        // Name label after image
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.coinImageView.trailingAnchor constant:12],
        [self.nameLabel.bottomAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-2],

        // Market supply below name
        [self.marketSupply.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.marketSupply.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:2],
        [self.marketSupply.topAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:2],

        // Price label: right-aligned, centerY aligned to the combined stack
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.sparklineView.leadingAnchor constant:-45],
        [self.priceLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

        // Sparkline view: right of price, top of stack
        [self.sparklineView.topAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-16],
        [self.sparklineView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.sparklineView.widthAnchor constraintEqualToConstant:60],
        [self.sparklineView.heightAnchor constraintEqualToConstant:20],

        // Percent change label: below sparkline
        [self.percentChangeLabel.topAnchor constraintEqualToAnchor:self.sparklineView.bottomAnchor constant:2],
        [self.percentChangeLabel.trailingAnchor constraintEqualToAnchor:self.sparklineView.trailingAnchor],
        [self.percentChangeLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-8],
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

// Resets the image when cells are reused by the collection view.
// Avoids image flickering / wrong images showing
- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coinImageView setPlaceholder];
}

@end
