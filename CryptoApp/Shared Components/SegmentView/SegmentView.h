//
//  SegmentView.h
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SegmentView : UIView

@property (nonatomic, copy) void (^onSelectionChanged)(NSInteger selectedIndex);
- (void)configureWithItems:(NSArray<NSString *> *)items;
- (void)setSelectedIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END

