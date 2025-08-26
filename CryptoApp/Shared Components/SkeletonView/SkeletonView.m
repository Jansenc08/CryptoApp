//
//  SkeletonView.m
//  CryptoApp
//
//  Created by Jansen Castillo
//

#import "SkeletonView.h"

@interface SkeletonView ()

@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, assign) BOOL isAnimating;

@end

@implementation SkeletonView

// MARK: - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSkeleton];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupSkeleton];
    }
    return self;
}

// MARK: - Deallocation

- (void)dealloc {
    [self stopShimmering];
}

// MARK: - Setup

- (void)setupSkeleton {
    self.backgroundColor = [UIColor systemGray5Color];
    self.layer.cornerRadius = 4.0;
    
    // Setup gradient layer for shimmer effect
    self.gradientLayer = [[CAGradientLayer alloc] init];
    self.gradientLayer.colors = @[
        (id)[UIColor systemGray5Color].CGColor,
        (id)[UIColor systemGray4Color].CGColor,
        (id)[UIColor systemGray5Color].CGColor
    ];
    self.gradientLayer.locations = @[@0, @0.5, @1];
    self.gradientLayer.startPoint = CGPointMake(0, 0.5);
    self.gradientLayer.endPoint = CGPointMake(1, 0.5);
    [self.layer addSublayer:self.gradientLayer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
}

// MARK: - Animation

- (void)startShimmering {
    if (self.isAnimating) {
        return;
    }
    self.isAnimating = YES;
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"locations"];
    animation.fromValue = @[@(-1.0), @(-0.5), @(0.0)];
    animation.toValue = @[@(1.0), @(1.5), @(2.0)];
    animation.duration = 1.5;
    animation.repeatCount = INFINITY;
    [self.gradientLayer addAnimation:animation forKey:@"shimmer"];
}

- (void)stopShimmering {
    self.isAnimating = NO;
    if (self.gradientLayer) {
        [self.gradientLayer removeAnimationForKey:@"shimmer"];
    }
}

// MARK: - Convenience Factory Methods

+ (instancetype)textSkeletonWithWidth:(CGFloat)width height:(CGFloat)height {
    SkeletonView *skeleton = [[SkeletonView alloc] init];
    skeleton.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [skeleton.widthAnchor constraintEqualToConstant:width],
        [skeleton.heightAnchor constraintEqualToConstant:height]
    ]];
    return skeleton;
}

+ (instancetype)circleSkeletonWithDiameter:(CGFloat)diameter {
    SkeletonView *skeleton = [[SkeletonView alloc] init];
    skeleton.translatesAutoresizingMaskIntoConstraints = NO;
    skeleton.layer.cornerRadius = diameter / 2.0;
    [NSLayoutConstraint activateConstraints:@[
        [skeleton.widthAnchor constraintEqualToConstant:diameter],
        [skeleton.heightAnchor constraintEqualToConstant:diameter]
    ]];
    return skeleton;
}

+ (instancetype)rectangleSkeletonWithWidth:(CGFloat)width height:(CGFloat)height cornerRadius:(CGFloat)cornerRadius {
    SkeletonView *skeleton = [[SkeletonView alloc] init];
    skeleton.translatesAutoresizingMaskIntoConstraints = NO;
    skeleton.layer.cornerRadius = cornerRadius;
    [NSLayoutConstraint activateConstraints:@[
        [skeleton.widthAnchor constraintEqualToConstant:width],
        [skeleton.heightAnchor constraintEqualToConstant:height]
    ]];
    return skeleton;
}

+ (instancetype)resizableSkeletonWithCornerRadius:(CGFloat)cornerRadius {
    SkeletonView *skeleton = [[SkeletonView alloc] init];
    skeleton.translatesAutoresizingMaskIntoConstraints = NO;
    skeleton.layer.cornerRadius = cornerRadius;
    return skeleton;
}

@end

// MARK: - Container View for Multiple Skeletons

@interface SkeletonContainerView ()

@property (nonatomic, strong) NSMutableArray<SkeletonView *> *skeletonViews;

@end

@implementation SkeletonContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.skeletonViews = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        self.skeletonViews = [[NSMutableArray alloc] init];
    }
    return self;
}

// MARK: - Deallocation

- (void)dealloc {
    [self stopShimmering];
    [self removeAllSkeletons];
}

- (void)addSkeletonViews:(NSArray<SkeletonView *> *)views {
    [self.skeletonViews addObjectsFromArray:views];
    for (SkeletonView *view in views) {
        [self addSubview:view];
    }
}

- (void)startShimmering {
    for (SkeletonView *skeletonView in self.skeletonViews) {
        [skeletonView startShimmering];
    }
}

- (void)stopShimmering {
    for (SkeletonView *skeletonView in self.skeletonViews) {
        [skeletonView stopShimmering];
    }
}

- (void)removeAllSkeletons {
    if (self.skeletonViews) {
        for (SkeletonView *skeletonView in self.skeletonViews) {
            [skeletonView stopShimmering];
            [skeletonView removeFromSuperview];
        }
        [self.skeletonViews removeAllObjects];
    }
}

@end
