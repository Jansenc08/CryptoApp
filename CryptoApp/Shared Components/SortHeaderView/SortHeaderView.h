
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CryptoSortColumn) {
    CryptoSortColumnRank,
    CryptoSortColumnMarketCap,
    CryptoSortColumnPrice,
    CryptoSortColumnPriceChange
};

typedef NS_ENUM(NSUInteger, CryptoSortOrder) {
    CryptoSortOrderAscending,
    CryptoSortOrderDescending
};

@class SortHeaderView;

@protocol SortHeaderViewDelegate <NSObject>
- (void)sortHeaderView:(SortHeaderView *)headerView didSelect:(CryptoSortColumn)column order:(CryptoSortOrder)order;
@end

@interface SortHeaderView : UIView

@property (nonatomic, weak) id<SortHeaderViewDelegate> delegate;
@property (nonatomic, assign) CryptoSortColumn currentSortColumn;
@property (nonatomic, assign) CryptoSortOrder currentSortOrder;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)updatePriceChangeColumnTitle:(NSString *)title; // Updates "1h%", "24h%", etc.
- (void)updateSortIndicators; // Updates sort arrow indicators

@end

NS_ASSUME_NONNULL_END 
