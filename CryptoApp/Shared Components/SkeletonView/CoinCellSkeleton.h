//
//  CoinCellSkeleton.h
//  CryptoApp
//
//  Created by Jansen Castillo
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CoinCellSkeleton : UICollectionViewCell

// MARK: - Public Methods
- (void)startShimmering;
- (void)stopShimmering;

// MARK: - Reuse Identifier
+ (NSString *)reuseID;

@end

NS_ASSUME_NONNULL_END
