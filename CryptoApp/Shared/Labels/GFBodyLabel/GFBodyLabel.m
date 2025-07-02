//
//  GFBodyLabel.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import <Foundation/Foundation.h>
#import "GFBodyLabel.h"

@implementation GFBodyLabel

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self configure];
    }
    return self;
}

- (instancetype)initWithTextAlignment:(NSTextAlignment)textAlignment
                             fontSize:(CGFloat)fontSize
                               weight:(UIFontWeight)weight {
    self = [self init];
    if (self) {
        self.textAlignment = textAlignment;
        self.font = [UIFont systemFontOfSize:fontSize weight:weight];
    }
    return self;
}

- (void)configure {
    self.textColor = [UIColor labelColor];
    self.adjustsFontSizeToFitWidth = YES;
    self.adjustsFontForContentSizeCategory = YES;
    self.minimumScaleFactor = 0.8;
    self.numberOfLines = 1;
    self.translatesAutoresizingMaskIntoConstraints = NO;
}

@end
