//
//  LoadingView.m
//  CryptoApp
//
//  Created by Jansen Castillo on 2/7/25.
//
#import "LoadingView.h"

@implementation LoadingView

+ (instancetype)showInView:(UIView *)parentView {
    LoadingView *loadingView = [[LoadingView alloc] initWithFrame:parentView.bounds];
    loadingView.backgroundColor = [UIColor systemBackgroundColor];
    loadingView.alpha = 0.0;

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [loadingView addSubview:indicator];

    [NSLayoutConstraint activateConstraints:@[
        [indicator.centerXAnchor constraintEqualToAnchor:loadingView.centerXAnchor],
        [indicator.centerYAnchor constraintEqualToAnchor:loadingView.centerYAnchor]
    ]];

    [parentView addSubview:loadingView];

    [UIView animateWithDuration:0.25 animations:^{
        loadingView.alpha = 0.8;
    }];

    [indicator startAnimating];

    return loadingView;
}

+ (void)dismissFromView:(UIView *)parentView {
    for (UIView *subview in parentView.subviews) {
        if ([subview isKindOfClass:[LoadingView class]]) {
            [UIView animateWithDuration:0.25 animations:^{
                subview.alpha = 0.0;
            } completion:^(BOOL finished) {
                [subview removeFromSuperview];
            }];
        }
    }
}

@end
