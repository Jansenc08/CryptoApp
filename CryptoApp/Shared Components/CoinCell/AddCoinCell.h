//
//  AddCoinCell.h
//  CryptoApp
//
//  Created by AI Assistant on 7/8/25.
//

#import <UIKit/UIKit.h>
#import "CoinImageView.h"

NS_ASSUME_NONNULL_BEGIN

@class GFBodyLabel;

@interface AddCoinCell : UICollectionViewCell

// UI Components
@property (nonatomic, strong) CoinImageView *coinImageView;
@property (nonatomic, strong) GFBodyLabel *symbolLabel;
@property (nonatomic, strong) GFBodyLabel *nameLabel;
@property (nonatomic, strong) UIView *selectionOverlay;
@property (nonatomic, strong) UIImageView *checkmarkImageView;

// Selection state
@property (nonatomic, assign) BOOL isSelectedForWatchlist;

// Configuration
- (void)configureWithSymbol:(NSString *)symbol
                       name:(NSString *)name
                   logoURL:(nullable NSString *)logoURL
                 isSelected:(BOOL)isSelected;

// Selection management
- (void)setSelectedForWatchlist:(BOOL)selected animated:(BOOL)animated;

// Reuse identifier
+ (NSString *)reuseID;

@end

NS_ASSUME_NONNULL_END 