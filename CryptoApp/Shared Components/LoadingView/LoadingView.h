//
//  LoadingView.h
//  CryptoApp
//
//  Created by Jansen Castillo on 2/7/25.
//

#import <UIKit/UIKit.h>

@interface LoadingView : UIView
// Class Method
+ (instancetype)showInView:(UIView *)parentView NS_SWIFT_NAME(show(in:));
+ (void)dismissFromView:(UIView *)parentView NS_SWIFT_NAME(dismiss(from:));

@end
