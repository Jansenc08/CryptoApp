# Skeleton Loading System

This skeleton loading system replaces basic activity indicators with sophisticated skeleton screens that provide better UX by showing the structure of content while it loads.

## Components

### Core Components

1. **SkeletonView** - Base skeleton component with shimmer animation
2. **SkeletonContainerView** - Container for managing multiple skeleton views
3. **SkeletonLoadingManager** - Central manager for showing/hiding skeleton screens

### Skeleton Cell Types

1. **CoinCellSkeleton** - Mimics the CoinCell layout with:
   - Rank placeholder (20x12)
   - Circular coin image placeholder (32x32)
   - Name and market cap text placeholders
   - Price and percentage change placeholders
   - Sparkline chart placeholder (60x20)

2. **AddCoinCellSkeleton** - Mimics the AddCoinCell layout with:
   - Circular coin image placeholder (40x40)
   - Symbol text placeholder (60x16)
   - Name text placeholder (80x14)

3. **ChartSkeleton** - Mimics chart layout with:
   - Main chart area with axis labels
   - Y-axis labels (left side)
   - X-axis labels (bottom)

## Implementation

### Collection View Loading
```swift
// Show skeleton loading
SkeletonLoadingManager.showSkeletonInCollectionView(collectionView, cellType: .coinCell, numberOfItems: 10)

// Hide skeleton loading and restore data source
SkeletonLoadingManager.dismissSkeletonFromCollectionView(collectionView)
collectionView.dataSource = originalDataSource
collectionView.reloadData()
```

### Chart Loading
```swift
// Show chart skeleton
let chartSkeleton = SkeletonLoadingManager.showChartSkeleton(in: containerView)

// Hide chart skeleton
SkeletonLoadingManager.dismissChartSkeleton(from: containerView)
```

## Features

- **Shimmer Animation**: Smooth gradient animation that simulates loading
- **Responsive Layout**: Matches the exact layout of actual content
- **Multiple Cell Types**: Supports different skeleton types for different contexts
- **Automatic Management**: Handles animation lifecycle and memory management
- **Seamless Integration**: Drop-in replacement for existing LoadingView usage

## Updated View Controllers

1. **CoinListVC** - Uses CoinCellSkeleton (10 items)
2. **WatchlistVC** - Uses CoinCellSkeleton (8 items) 
3. **AddCoinsVC** - Uses AddCoinCellSkeleton (12 items)
4. **SearchVC** - Uses CoinCellSkeleton for popular coins (6 items)
5. **ChartCell** - Uses ChartSkeleton for chart loading
6. **LandscapeChartVC** - Uses ChartSkeleton for landscape charts

## Benefits

- **Better UX**: Users see content structure while loading
- **Reduced Perceived Load Time**: Skeleton screens make loading feel faster
- **Consistent Design**: All loading states follow the same visual pattern
- **Smooth Animations**: Shimmer effect provides engaging feedback
- **Context Awareness**: Different skeleton types for different content types 