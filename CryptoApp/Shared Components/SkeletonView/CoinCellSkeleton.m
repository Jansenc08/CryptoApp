//
//  CoinCellSkeleton.m
//  CryptoApp
//
//  Created by Jansen Castillo
//

#import "CoinCellSkeleton.h"
#import "SkeletonView.h"

@interface CoinCellSkeleton ()

@property (nonatomic, strong) NSArray<SkeletonView *> *skeletonViews;

// Layout components to match CoinCell
@property (nonatomic, strong) SkeletonView *rankSkeleton;
@property (nonatomic, strong) SkeletonView *imageSkeleton;
@property (nonatomic, strong) SkeletonView *nameSkeleton;
@property (nonatomic, strong) SkeletonView *marketSkeleton;
@property (nonatomic, strong) SkeletonView *priceSkeleton;
@property (nonatomic, strong) SkeletonView *sparklineSkeleton;
@property (nonatomic, strong) SkeletonView *percentSkeleton;

// Stack views to match CoinCell layout
@property (nonatomic, strong) UIStackView *nameStack;
@property (nonatomic, strong) UIStackView *leftStack;
@property (nonatomic, strong) UIStackView *sparklineAndPercentStack;
@property (nonatomic, strong) UIStackView *rightStack;
@property (nonatomic, strong) UIStackView *mainStack;

@end

@implementation CoinCellSkeleton

// MARK: - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self collectSkeletonViews];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupUI];
        [self collectSkeletonViews];
    }
    return self;
}

// MARK: - Setup

- (void)setupUI {
    [self createSkeletonViews];
    [self createStackViews];
    [self layoutStackViews];
    [self applyConstraints];
}

- (void)createSkeletonViews {
    self.rankSkeleton = [SkeletonView textSkeletonWithWidth:20 height:12];
    self.imageSkeleton = [SkeletonView circleSkeletonWithDiameter:32];
    self.nameSkeleton = [SkeletonView textSkeletonWithWidth:80 height:14];
    self.marketSkeleton = [SkeletonView textSkeletonWithWidth:60 height:12];
    self.priceSkeleton = [SkeletonView textSkeletonWithWidth:70 height:14];
    self.sparklineSkeleton = [SkeletonView rectangleSkeletonWithWidth:60 height:20 cornerRadius:2];
    self.percentSkeleton = [SkeletonView textSkeletonWithWidth:50 height:12];
}

- (void)createStackViews {
    // Name stack (vertical)
    self.nameStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.nameSkeleton, self.marketSkeleton]];
    self.nameStack.axis = UILayoutConstraintAxisVertical;
    self.nameStack.spacing = 2;
    self.nameStack.alignment = UIStackViewAlignmentLeading;
    
    // Left stack (horizontal)
    self.leftStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.rankSkeleton, self.imageSkeleton, self.nameStack]];
    self.leftStack.axis = UILayoutConstraintAxisHorizontal;
    self.leftStack.alignment = UIStackViewAlignmentCenter;
    self.leftStack.spacing = 12;
    self.leftStack.distribution = UIStackViewDistributionFill;
    
    // Sparkline and percent stack (vertical)
    self.sparklineAndPercentStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.sparklineSkeleton, self.percentSkeleton]];
    self.sparklineAndPercentStack.axis = UILayoutConstraintAxisVertical;
    self.sparklineAndPercentStack.spacing = 4;
    self.sparklineAndPercentStack.alignment = UIStackViewAlignmentCenter;
    
    // Right stack (horizontal)
    self.rightStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.priceSkeleton, self.sparklineAndPercentStack]];
    self.rightStack.axis = UILayoutConstraintAxisHorizontal;
    self.rightStack.alignment = UIStackViewAlignmentCenter;
    self.rightStack.spacing = 16;
    self.rightStack.distribution = UIStackViewDistributionFill;
    
    // Main stack (horizontal)
    self.mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.leftStack, self.rightStack]];
    self.mainStack.axis = UILayoutConstraintAxisHorizontal;
    self.mainStack.alignment = UIStackViewAlignmentCenter;
    self.mainStack.distribution = UIStackViewDistributionFillProportionally;
    self.mainStack.spacing = 16;
    self.mainStack.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)layoutStackViews {
    [self.contentView addSubview:self.mainStack];
}

- (void)applyConstraints {
    // Match CoinCell constraints exactly
    [NSLayoutConstraint activateConstraints:@[
        [self.mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        // Fixed sizes to match CoinCell
        [self.rankSkeleton.widthAnchor constraintGreaterThanOrEqualToConstant:20],
        [self.nameSkeleton.widthAnchor constraintGreaterThanOrEqualToConstant:80],
        [self.priceSkeleton.widthAnchor constraintGreaterThanOrEqualToConstant:70],
        [self.sparklineAndPercentStack.widthAnchor constraintGreaterThanOrEqualToConstant:60]
    ]];
    
    // Set content hugging priorities to match CoinCell
    [self.rankSkeleton setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.imageSkeleton setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.sparklineSkeleton setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.sparklineAndPercentStack setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)collectSkeletonViews {
    self.skeletonViews = @[
        self.rankSkeleton,
        self.imageSkeleton,
        self.nameSkeleton,
        self.marketSkeleton,
        self.priceSkeleton,
        self.sparklineSkeleton,
        self.percentSkeleton
    ];
}

// MARK: - Public Methods

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

// MARK: - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    [self stopShimmering];
}

+ (NSString *)reuseID {
    return @"CoinCellSkeleton";
}

@end
