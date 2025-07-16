//
//  SegmentControl.h
//  CryptoApp
//
//  Created by Assistant on 25/6/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SegmentControl;

@protocol SegmentControlDelegate <NSObject>
- (void)segmentControl:(SegmentControl *)segmentControl didSelectSegmentAt:(NSInteger)index;
@end

@interface SegmentControl : UIView

@property (nonatomic, weak) id<SegmentControlDelegate> delegate;
@property (nonatomic, assign) NSInteger selectedSegmentIndex;

- (instancetype)initWithItems:(NSArray<NSString *> *)items;
- (void)setSelectedSegmentIndex:(NSInteger)index animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END 