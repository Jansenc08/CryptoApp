//
//  ChartSkeleton.m
//  CryptoApp
//
//  Created by Jansen Castillo
//

#import "ChartSkeleton.h"
#import "SkeletonView.h"

@interface ChartSkeleton ()

@property (nonatomic, strong) NSArray<SkeletonView *> *skeletonViews;
@property (nonatomic, strong) UIView *containerView;

// Chart skeleton components
@property (nonatomic, strong) SkeletonView *chartAreaSkeleton;
@property (nonatomic, strong) SkeletonView *yAxisLabelsSkeleton1;
@property (nonatomic, strong) SkeletonView *yAxisLabelsSkeleton2;
@property (nonatomic, strong) SkeletonView *yAxisLabelsSkeleton3;
@property (nonatomic, strong) SkeletonView *xAxisLabelsSkeleton1;
@property (nonatomic, strong) SkeletonView *xAxisLabelsSkeleton2;
@property (nonatomic, strong) SkeletonView *xAxisLabelsSkeleton3;

@end

@implementation ChartSkeleton

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
    [self configureAppearance];
    [self layoutViews];
    [self setupConstraints];
}

- (void)createSkeletonViews {
    self.chartAreaSkeleton = [SkeletonView resizableSkeletonWithCornerRadius:8];
    self.yAxisLabelsSkeleton1 = [SkeletonView textSkeletonWithWidth:40 height:12];
    self.yAxisLabelsSkeleton2 = [SkeletonView textSkeletonWithWidth:40 height:12];
    self.yAxisLabelsSkeleton3 = [SkeletonView textSkeletonWithWidth:40 height:12];
    self.xAxisLabelsSkeleton1 = [SkeletonView textSkeletonWithWidth:30 height:12];
    self.xAxisLabelsSkeleton2 = [SkeletonView textSkeletonWithWidth:30 height:12];
    self.xAxisLabelsSkeleton3 = [SkeletonView textSkeletonWithWidth:30 height:12];
}

- (void)configureAppearance {
    self.backgroundColor = [UIColor systemBackgroundColor];
    
    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)layoutViews {
    [self addSubview:self.containerView];
    
    // Add all skeleton components
    [self.containerView addSubview:self.chartAreaSkeleton];
    [self.containerView addSubview:self.yAxisLabelsSkeleton1];
    [self.containerView addSubview:self.yAxisLabelsSkeleton2];
    [self.containerView addSubview:self.yAxisLabelsSkeleton3];
    [self.containerView addSubview:self.xAxisLabelsSkeleton1];
    [self.containerView addSubview:self.xAxisLabelsSkeleton2];
    [self.containerView addSubview:self.xAxisLabelsSkeleton3];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Container fills the view
        [self.containerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16],
        
        // Chart area skeleton (main chart area) - adjusted for right-side Y-axis
        [self.chartAreaSkeleton.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.chartAreaSkeleton.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.chartAreaSkeleton.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-50],
        [self.chartAreaSkeleton.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-30],
        
        // Y-axis labels (RIGHT side - matching your chart layout)
        [self.yAxisLabelsSkeleton1.topAnchor constraintEqualToAnchor:self.chartAreaSkeleton.topAnchor],
        [self.yAxisLabelsSkeleton1.leadingAnchor constraintEqualToAnchor:self.chartAreaSkeleton.trailingAnchor constant:8],
        
        [self.yAxisLabelsSkeleton2.centerYAnchor constraintEqualToAnchor:self.chartAreaSkeleton.centerYAnchor],
        [self.yAxisLabelsSkeleton2.leadingAnchor constraintEqualToAnchor:self.chartAreaSkeleton.trailingAnchor constant:8],
        
        [self.yAxisLabelsSkeleton3.bottomAnchor constraintEqualToAnchor:self.chartAreaSkeleton.bottomAnchor],
        [self.yAxisLabelsSkeleton3.leadingAnchor constraintEqualToAnchor:self.chartAreaSkeleton.trailingAnchor constant:8],
        
        // X-axis labels (bottom)
        [self.xAxisLabelsSkeleton1.topAnchor constraintEqualToAnchor:self.chartAreaSkeleton.bottomAnchor constant:8],
        [self.xAxisLabelsSkeleton1.leadingAnchor constraintEqualToAnchor:self.chartAreaSkeleton.leadingAnchor],
        
        [self.xAxisLabelsSkeleton2.topAnchor constraintEqualToAnchor:self.chartAreaSkeleton.bottomAnchor constant:8],
        [self.xAxisLabelsSkeleton2.centerXAnchor constraintEqualToAnchor:self.chartAreaSkeleton.centerXAnchor],
        
        [self.xAxisLabelsSkeleton3.topAnchor constraintEqualToAnchor:self.chartAreaSkeleton.bottomAnchor constant:8],
        [self.xAxisLabelsSkeleton3.trailingAnchor constraintEqualToAnchor:self.chartAreaSkeleton.trailingAnchor]
    ]];
}

- (void)collectSkeletonViews {
    self.skeletonViews = @[
        self.chartAreaSkeleton,
        self.yAxisLabelsSkeleton1,
        self.yAxisLabelsSkeleton2,
        self.yAxisLabelsSkeleton3,
        self.xAxisLabelsSkeleton1,
        self.xAxisLabelsSkeleton2,
        self.xAxisLabelsSkeleton3
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

- (void)removeFromParent {
    [self stopShimmering];
    [self removeFromSuperview];
}

@end
