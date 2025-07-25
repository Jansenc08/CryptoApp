//
//  SegmentView.m
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

#import "SegmentView.h"

@interface SegmentView ()
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@end

@implementation SegmentView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.segmentedControl = [[UISegmentedControl alloc] init];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.segmentedControl];

    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.segmentedControl.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
    ]];
}

- (void)configureWithItems:(NSArray<NSString *> *)items {
    [self.segmentedControl removeAllSegments];
    for (NSInteger i = 0; i < items.count; i++) {
        [self.segmentedControl insertSegmentWithTitle:items[i] atIndex:i animated:NO];
    }
    self.segmentedControl.selectedSegmentIndex = 0;
}

- (void)setSelectedIndex:(NSInteger)index {
    if (index >= 0 && index < self.segmentedControl.numberOfSegments) {
        self.segmentedControl.selectedSegmentIndex = index;
    }
}

- (void)setSelectedIndexSilently:(NSInteger)index {
    if (index >= 0 && index < self.segmentedControl.numberOfSegments) {
        // Temporarily disable the callback to prevent recursive updates
        id originalCallback = self.onSelectionChanged;
        self.onSelectionChanged = nil;
        
        // Update selection without animation
        [UIView performWithoutAnimation:^{
            self.segmentedControl.selectedSegmentIndex = index;
        }];
        
        // Restore the callback
        self.onSelectionChanged = originalCallback;
    }
}

- (void)valueChanged:(UISegmentedControl *)sender {
    if (self.onSelectionChanged) {
        self.onSelectionChanged(sender.selectedSegmentIndex);
    }
}

@end
