//
//  SegmentControl.m
//  CryptoApp
//
//  Created by Assistant on 25/6/25.
//

#import "SegmentControl.h"

@interface SegmentControl ()

@property (nonatomic, strong) NSArray<NSString *> *segmentTitles;
@property (nonatomic, strong) NSMutableArray<UIButton *> *segmentButtons;
@property (nonatomic, strong) UIView *underlineIndicator;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) NSLayoutConstraint *underlineLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *underlineWidthConstraint;

@end

@implementation SegmentControl

- (instancetype)initWithItems:(NSArray<NSString *> *)items {
    self = [super init];
    if (self) {
        _segmentTitles = items;
        _selectedSegmentIndex = 0;
        _segmentButtons = [[NSMutableArray alloc] init];
        [self setupSegmentControl];
        [self setupConstraints];
        [self setupGestureRecognizers];
    }
    return self;
}

- (void)setupSegmentControl {
    // Clean background - no box styling
    self.backgroundColor = [UIColor clearColor];
    
    // Create segment buttons
    for (NSInteger i = 0; i < self.segmentTitles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = i;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        
        // 🔵 Completely remove blue highlight/selection box
        button.backgroundColor = [UIColor clearColor];
        
        // Use modern UIButtonConfiguration for iOS 15+ to avoid deprecation warnings
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
            config.title = self.segmentTitles[i];
            config.baseForegroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            config.background.backgroundColor = [UIColor clearColor];
            config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull textAttributes) {
                NSMutableDictionary *attrs = [textAttributes mutableCopy];
                attrs[NSFontAttributeName] = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
                return attrs;
            };
            
            button.configuration = config;
            
            // Remove highlight behavior using configuration update handler
            button.configurationUpdateHandler = ^(UIButton * _Nonnull button) {
                button.configuration.background.backgroundColor = [UIColor clearColor];
                button.configuration.baseForegroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            };
        } else {
            // Fallback for iOS 14 and earlier
            [button setTitle:self.segmentTitles[i] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0] forState:UIControlStateSelected];
            button.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
            
            button.adjustsImageWhenHighlighted = NO;
            button.showsTouchWhenHighlighted = NO;
            
            // Remove all background images for all states
            [button setBackgroundImage:nil forState:UIControlStateNormal];
            [button setBackgroundImage:nil forState:UIControlStateHighlighted];
            [button setBackgroundImage:nil forState:UIControlStateSelected];
            [button setBackgroundImage:nil forState:UIControlStateDisabled];
            
            // Override title color for highlighted state to match normal state
            [button setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0] forState:UIControlStateHighlighted];
        }
        
        // Remove tint color that causes blue highlight
        button.tintColor = [UIColor clearColor];
        
        [button addTarget:self action:@selector(segmentButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:button];
        [self.segmentButtons addObject:button];
    }
    
    // Underline indicator (CoinMarketCap style)
    self.underlineIndicator = [[UIView alloc] init];
    self.underlineIndicator.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0]; // CMC blue
    self.underlineIndicator.layer.cornerRadius = 1.5; // Slightly rounded edges
    self.underlineIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.underlineIndicator];
    
    // Set initial selected state
    if (self.segmentButtons.count > 0) {
        self.segmentButtons[0].selected = YES;
    }
}

- (void)setupConstraints {
    // Set control height
    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:44.0]
    ]];
    
    // Button constraints - clean layout without background padding
    UIButton *previousButton = nil;
    for (NSInteger i = 0; i < self.segmentButtons.count; i++) {
        UIButton *button = self.segmentButtons[i];
        
        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor constraintEqualToAnchor:self.topAnchor],
            [button.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4.0] // Leave space for underline
        ]];
        
        if (i == 0) {
            // First button
            [button.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
        } else {
            // Subsequent buttons
            [button.leadingAnchor constraintEqualToAnchor:previousButton.trailingAnchor constant:20.0].active = YES; // Add spacing between buttons
            [button.widthAnchor constraintEqualToAnchor:previousButton.widthAnchor].active = YES;
        }
        
        if (i == self.segmentButtons.count - 1) {
            // Last button
            [button.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
        }
        
        previousButton = button;
    }
    
    // Underline indicator constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.underlineIndicator.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.underlineIndicator.heightAnchor constraintEqualToConstant:3.0] // Thin underline
    ]];
    
    // Initialize underline position constraints
    UIButton *firstButton = self.segmentButtons[0];
    self.underlineLeadingConstraint = [self.underlineIndicator.leadingAnchor constraintEqualToAnchor:firstButton.leadingAnchor];
    self.underlineWidthConstraint = [self.underlineIndicator.widthAnchor constraintEqualToAnchor:firstButton.widthAnchor];
    
    [NSLayoutConstraint activateConstraints:@[
        self.underlineLeadingConstraint,
        self.underlineWidthConstraint
    ]];
}

- (void)setupGestureRecognizers {
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    [self addGestureRecognizer:self.panGestureRecognizer];
}

- (void)segmentButtonTapped:(UIButton *)sender {
    [self setSelectedSegmentIndex:sender.tag animated:YES];
    
    if ([self.delegate respondsToSelector:@selector(segmentControl:didSelectSegmentAt:)]) {
        [self.delegate segmentControl:self didSelectSegmentAt:sender.tag];
    }
}

- (void)setSelectedSegmentIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= self.segmentButtons.count) {
        return;
    }
    
    // Update all button states and colors to prevent blue highlighting
    for (NSInteger i = 0; i < self.segmentButtons.count; i++) {
        UIButton *button = self.segmentButtons[i];
        button.selected = (i == index);
        
        UIColor *textColor;
        if (i == index) {
            // Selected button - dark text
            textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
        } else {
            // Unselected button - gray text
            textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        }
        
        // Update colors based on iOS version
        if (@available(iOS 15.0, *)) {
            // Use UIButtonConfiguration for iOS 15+
            if (button.configuration != nil) {
                UIButtonConfiguration *config = button.configuration;
                config.baseForegroundColor = textColor;
                button.configuration = config;
                
                // Update configuration handler to maintain color
                button.configurationUpdateHandler = ^(UIButton * _Nonnull btn) {
                    btn.configuration.background.backgroundColor = [UIColor clearColor];
                    btn.configuration.baseForegroundColor = textColor;
                };
            }
        } else {
            // Fallback for iOS 14 and earlier
            [button setTitleColor:textColor forState:UIControlStateNormal];
            [button setTitleColor:textColor forState:UIControlStateHighlighted];
        }
        
        // Force clear background and remove any blue tinting
        button.backgroundColor = [UIColor clearColor];
        button.tintColor = [UIColor clearColor];
    }
    
    _selectedSegmentIndex = index;
    
    [self updateIndicatorPosition:animated];
}

- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex {
    [self setSelectedSegmentIndex:selectedSegmentIndex animated:NO];
}

- (void)updateIndicatorPosition:(BOOL)animated {
    if (self.selectedSegmentIndex >= self.segmentButtons.count) return;
    
    UIButton *selectedButton = self.segmentButtons[self.selectedSegmentIndex];
    
    // Update existing constraints instead of removing/adding
    self.underlineLeadingConstraint.active = NO;
    self.underlineWidthConstraint.active = NO;
    
    self.underlineLeadingConstraint = [self.underlineIndicator.leadingAnchor constraintEqualToAnchor:selectedButton.leadingAnchor];
    self.underlineWidthConstraint = [self.underlineIndicator.widthAnchor constraintEqualToAnchor:selectedButton.widthAnchor];
    
    self.underlineLeadingConstraint.active = YES;
    self.underlineWidthConstraint.active = YES;
    
    if (animated) {
        [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self layoutIfNeeded];
        } completion:nil];
    } else {
        [self layoutIfNeeded];
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    CGPoint velocity = [gesture velocityInView:self];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // More responsive thresholds for better UX
        CGFloat swipeThreshold = 30.0; // Lower threshold
        CGFloat velocityThreshold = 300.0; // Lower velocity threshold
        
        BOOL shouldSwipeLeft = (translation.x < -swipeThreshold || velocity.x < -velocityThreshold);
        BOOL shouldSwipeRight = (translation.x > swipeThreshold || velocity.x > velocityThreshold);
        
        NSInteger newIndex = self.selectedSegmentIndex;
        
        if (shouldSwipeLeft && self.selectedSegmentIndex < self.segmentButtons.count - 1) {
            // Swipe left -> next segment
            newIndex = self.selectedSegmentIndex + 1;
        } else if (shouldSwipeRight && self.selectedSegmentIndex > 0) {
            // Swipe right -> previous segment
            newIndex = self.selectedSegmentIndex - 1;
        }
        
        if (newIndex != self.selectedSegmentIndex) {
            [self setSelectedSegmentIndex:newIndex animated:YES];
            
            if ([self.delegate respondsToSelector:@selector(segmentControl:didSelectSegmentAt:)]) {
                [self.delegate segmentControl:self didSelectSegmentAt:newIndex];
            }
        }
    }
}

@end 
