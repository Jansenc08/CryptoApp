//
//  CoinCell.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import <Foundation/Foundation.h>
#import "CoinCell.h"
#import "GFBodyLabel.h"

@implementation CoinCell

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
    self.rankLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:14 weight:UIFontWeightMedium];
    self.coinImageView = [[CoinImageView alloc] init];
    [self.contentView addSubview:self.coinImageView];
    self.nameLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:16 weight:UIFontWeightSemibold];
    self.priceLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:14 weight:UIFontWeightMedium];
    self.percentChangeLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:14 weight:UIFontWeightMedium];
    self.marketSupply = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:14 weight:UIFontWeightMedium];

    [self.contentView addSubview:self.rankLabel];
    [self.contentView addSubview:self.coinImageView];
    [self.contentView addSubview:self.nameLabel];
    [self.contentView addSubview:self.priceLabel];
    [self.contentView addSubview:self.marketSupply];
    [self.contentView addSubview:self.percentChangeLabel];


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
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],

        [self.marketSupply.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.marketSupply.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.marketSupply.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

        // Price label: right-aligned & centered vertically
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-80],
        [self.priceLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

        // Percent change label: beside price & vertically aligned
        [self.percentChangeLabel.leadingAnchor constraintEqualToAnchor:self.priceLabel.trailingAnchor constant:8],
        [self.percentChangeLabel.centerYAnchor constraintEqualToAnchor:self.priceLabel.centerYAnchor],
        [self.percentChangeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-12],

    ]];
}


- (void)configureWithRank:(NSInteger)rank
                     name:(NSString *)name
                    price:(NSString *)price
                    market:(NSString *)market
         percentChange24h:(NSString *)percentChange24h{
    self.rankLabel.text = [NSString stringWithFormat:@"%ld", (long)rank];
    self.nameLabel.text = name;
    self.priceLabel.text = price;
    self.marketSupply.text = market;
    self.percentChangeLabel.text = percentChange24h;
}

// Resets her image when cells are reused by the collection view.
// Avoids image flickering / wrong images showing
- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coinImageView setPlaceholder];
}

@end
