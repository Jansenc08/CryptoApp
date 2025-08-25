//
//  AddCoinCellSkeleton.m
//  CryptoApp
//
//  Created by Jansen Castillo
//

#import "AddCoinCellSkeleton.h"
#import "SkeletonView.h"

@interface AddCoinCellSkeleton ()

@property (nonatomic, strong) NSArray<SkeletonView *> *skeletonViews;

// Layout components to match AddCoinCell
@property (nonatomic, strong) SkeletonView *imageSkeleton;
@property (nonatomic, strong) SkeletonView *symbolSkeleton;
@property (nonatomic, strong) SkeletonView *nameSkeleton;

@end

@implementation AddCoinCellSkeleton

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
    [self configureCellAppearance];
    [self layoutSkeletonViews];
    [self applyConstraints];
}

- (void)createSkeletonViews {
    self.imageSkeleton = [SkeletonView circleSkeletonWithDiameter:40];
    self.symbolSkeleton = [SkeletonView textSkeletonWithWidth:60 height:16];
    self.nameSkeleton = [SkeletonView textSkeletonWithWidth:80 height:14];
}

- (void)configureCellAppearance {
    // Match AddCoinCell styling
    self.backgroundColor = [UIColor systemBackgroundColor];
    self.layer.cornerRadius = 8.0;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0].CGColor;
}

- (void)layoutSkeletonViews {
    [self.contentView addSubview:self.imageSkeleton];
    [self.contentView addSubview:self.symbolSkeleton];
    [self.contentView addSubview:self.nameSkeleton];
}

- (void)applyConstraints {
    // Layout to match AddCoinCell (horizontal layout with image on left, text on right)
    [NSLayoutConstraint activateConstraints:@[
        // Image skeleton positioning (left side, centered vertically)
        [self.imageSkeleton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.imageSkeleton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        
        // Symbol skeleton positioning (right of image, top)
        [self.symbolSkeleton.leadingAnchor constraintEqualToAnchor:self.imageSkeleton.trailingAnchor constant:12],
        [self.symbolSkeleton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.symbolSkeleton.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-50], // Leave space for potential checkmark
        
        // Name skeleton positioning (right of image, below symbol)
        [self.nameSkeleton.leadingAnchor constraintEqualToAnchor:self.imageSkeleton.trailingAnchor constant:12],
        [self.nameSkeleton.topAnchor constraintEqualToAnchor:self.symbolSkeleton.bottomAnchor constant:2],
        [self.nameSkeleton.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-50],
        [self.nameSkeleton.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12]
    ]];
}

- (void)collectSkeletonViews {
    self.skeletonViews = @[
        self.imageSkeleton,
        self.symbolSkeleton,
        self.nameSkeleton
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
    return @"AddCoinCellSkeleton";
}

@end
