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
    self.symbolLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentLeft fontSize:14 weight:UIFontWeightRegular];
    self.priceLabel = [[GFBodyLabel alloc] initWithTextAlignment:NSTextAlignmentRight fontSize:14 weight:UIFontWeightMedium];

    [self.contentView addSubview:self.rankLabel];
    [self.contentView addSubview:self.coinImageView];
    [self.contentView addSubview:self.nameLabel];
    [self.contentView addSubview:self.symbolLabel];
    [self.contentView addSubview:self.priceLabel];

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

        [self.symbolLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.symbolLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.symbolLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

        // Price aligned right
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.priceLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor]
    ]];
}


- (void)configureWithRank:(NSInteger)rank
                     name:(NSString *)name
                   symbol:(NSString *)symbol
                    price:(NSString *)price {
    self.rankLabel.text = [NSString stringWithFormat:@"%ld", (long)rank];
    self.nameLabel.text = name;
    self.symbolLabel.text = symbol;
    self.priceLabel.text = price;
}


@end
