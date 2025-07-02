//
//  CoinCell.h
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//


#import <UIKit/UIKit.h>
#import "CoinImageView.h"
NS_ASSUME_NONNULL_BEGIN


@class GFBodyLabel;

@interface CoinCell : UICollectionViewCell

@property (nonatomic, strong) GFBodyLabel * rankLabel;
@property (nonatomic, strong) CoinImageView * coinImageView;
@property (nonatomic, strong) GFBodyLabel * nameLabel;
@property (nonatomic, strong) GFBodyLabel * symbolLabel;
@property (nonatomic, strong) GFBodyLabel * priceLabel;

- (void)configureWithRank:(NSInteger)rank
                     name:(NSString *)name
                   symbol:(NSString *)symbol
                    price:(NSString *)price;

+ (NSString * _Nonnull)reuseID;

@end

NS_ASSUME_NONNULL_END
