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
@property (nonatomic, strong) GFBodyLabel * nameLabel;
@property (nonatomic, strong) GFBodyLabel * priceLabel;
@property (nonatomic, strong) GFBodyLabel * marketSupply;
@property (nonatomic, strong) CoinImageView * coinImageView;
@property (nonatomic, strong) GFBodyLabel * percentChangeLabel;


- (void)configureWithRank:(NSInteger)rank
                     name:(NSString *)name
                    price:(NSString *)price
                   market:(NSString *)market
         percentChange24h:(NSString *)percentChange24h;

+ (NSString * _Nonnull)reuseID;

@end

NS_ASSUME_NONNULL_END
