#import <UIKit/UIKit.h>
#import "CoinImageView.h"

NS_ASSUME_NONNULL_BEGIN

@class GFBodyLabel;

// Selection type enum for different visual states
typedef NS_ENUM(NSInteger, AddCoinSelectionType) {
    AddCoinSelectionTypeAdd = 0,    // Blue with checkmark (for adding to watchlist)
    AddCoinSelectionTypeRemove = 1  // Red with X (for removing from watchlist)
};

@interface AddCoinCell : UICollectionViewCell

// UI Components
@property (nonatomic, strong) CoinImageView *coinImageView;
@property (nonatomic, strong) GFBodyLabel *symbolLabel;
@property (nonatomic, strong) GFBodyLabel *nameLabel;
@property (nonatomic, strong) UIView *selectionOverlay;
@property (nonatomic, strong) UIImageView *checkmarkImageView;

// Selection state
@property (nonatomic, assign) BOOL isSelectedForWatchlist;
@property (nonatomic, assign) AddCoinSelectionType selectionType;

// Configuration
- (void)configureWithSymbol:(NSString *)symbol
                       name:(NSString *)name
                   logoURL:(nullable NSString *)logoURL
                 isSelected:(BOOL)isSelected
              selectionType:(AddCoinSelectionType)selectionType;

// Selection management
- (void)setSelectedForWatchlist:(BOOL)selected 
                  selectionType:(AddCoinSelectionType)selectionType
                       animated:(BOOL)animated;

// Reuse identifier
+ (NSString *)reuseID;

@end

NS_ASSUME_NONNULL_END 
