//
//  FilterButton.h
//  CryptoApp
//
//  Created by AI Assistant on 7/7/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FilterButton : UIButton

@property (nonatomic, strong) UILabel *customTitleLabel;

- (instancetype)initWithTitle:(NSString *)title;
- (void)updateTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END 