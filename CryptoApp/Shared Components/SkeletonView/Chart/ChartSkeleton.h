//
//  ChartSkeleton.h
//  CryptoApp
//
//  Created by Jansen Castillo
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChartSkeleton : UIView

// MARK: - Public Methods
- (void)startShimmering;
- (void)stopShimmering;
- (void)removeFromParent;

@end

NS_ASSUME_NONNULL_END
