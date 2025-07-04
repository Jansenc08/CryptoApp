//
//  GFBodyLabel.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import <Foundation/Foundation.h>
#import "GFBodyLabel.h"

@implementation GFBodyLabel

// Calls superclass UILabel initializer
- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self configure]; // Calls Configure to apply default styling
    }
    return self;
}

- (instancetype)initWithTextAlignment:(NSTextAlignment)textAlignment
                             fontSize:(CGFloat)fontSize
                               weight:(UIFontWeight)weight {
    
    self = [self init]; // Calls custom init above. Sets Default frame and calls configure.
    if (self) {
        self.textAlignment = textAlignment;
        self.font = [UIFont systemFontOfSize:fontSize weight:weight];
    }
    return self;
}

- (void)configure {
    self.textColor = [UIColor labelColor]; // Default text color (dark/light mode)
    self.adjustsFontSizeToFitWidth = YES;  // Auto-shrink text
    self.adjustsFontForContentSizeCategory = YES;  // Support Dynamic Type
    self.minimumScaleFactor = 0.8;  // Allow shrinking to 80%
    self.numberOfLines = 1;  // Single-line label
    self.translatesAutoresizingMaskIntoConstraints = NO;  // Allow shrinking to 80%
}

@end
