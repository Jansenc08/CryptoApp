//
//  GFBodyLabel.h
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//


#import <UIKit/UIKit.h>

@interface GFBodyLabel : UILabel

// Custom Initializer 
- (instancetype)initWithTextAlignment:(NSTextAlignment)textAlignment
                             fontSize:(CGFloat)fontSize
                               weight:(UIFontWeight)weight;
@end

