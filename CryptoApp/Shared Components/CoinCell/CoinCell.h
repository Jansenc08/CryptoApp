//
//  CoinCell.h
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//
// Declares classes and UI Components

#import <UIKit/UIKit.h>
#import "CoinImageView.h"

NS_ASSUME_NONNULL_BEGIN

@class GFBodyLabel;
@class SparklineView;

@interface CoinCell : UICollectionViewCell

// strong: retains object in memmory
// nonatomic: Non thread safe but faster
@property (nonatomic, strong) GFBodyLabel *rankLabel;
@property (nonatomic, strong) GFBodyLabel *nameLabel;
@property (nonatomic, strong) GFBodyLabel *priceLabel;
@property (nonatomic, strong) GFBodyLabel *marketSupply;
@property (nonatomic, strong) CoinImageView *coinImageView;
@property (nonatomic, strong) SparklineView *sparklineView;
@property (nonatomic, strong) GFBodyLabel *percentChangeLabel;
@property (nonatomic, strong) UIStackView *leftStack;
@property (nonatomic, strong) UIStackView *rightStack;
@property (nonatomic, strong) UIStackView *mainStack;


// Set up Cell data
// - indicates this is a instance method
// This is called on an object
- (void)configureWithRank:(NSInteger)rank
                     name:(NSString *)name
                    price:(NSString *)price
                   market:(NSString *)market
         percentChange24h:(NSString *)percentChange24h
             sparklineData:(NSArray<NSNumber *> *)sparklineData
            isPositiveChange:(BOOL)isPositiveChange;


// reuse method returning reuse identifier
// + indicates this is a class mehtod
// This is called on the class itself 
+ (NSString *_Nonnull)reuseID;

@end

NS_ASSUME_NONNULL_END
