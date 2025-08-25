//
//  SkeletonView.h
//  CryptoApp
//
//  Created by Jansen Castillo
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SkeletonView : UIView

// MARK: - Animation Methods
- (void)startShimmering;
- (void)stopShimmering;

// MARK: - Convenience Factory Methods

/// Creates a skeleton view that mimics a text label
+ (instancetype)textSkeletonWithWidth:(CGFloat)width height:(CGFloat)height;

/// Creates a skeleton view that mimics a circular image
+ (instancetype)circleSkeletonWithDiameter:(CGFloat)diameter;

/// Creates a skeleton view that mimics a rectangular area
+ (instancetype)rectangleSkeletonWithWidth:(CGFloat)width height:(CGFloat)height cornerRadius:(CGFloat)cornerRadius;

/// Creates a skeleton view that will be sized by its container constraints
+ (instancetype)resizableSkeletonWithCornerRadius:(CGFloat)cornerRadius;

@end

// MARK: - Container View for Multiple Skeletons

@interface SkeletonContainerView : UIView

- (void)addSkeletonViews:(NSArray<SkeletonView *> *)views;
- (void)startShimmering;
- (void)stopShimmering;
- (void)removeAllSkeletons;

@end

NS_ASSUME_NONNULL_END
