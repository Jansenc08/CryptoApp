import UIKit

final class SkeletonLoadingManager {
    
    // MARK: - Static Methods for Collection Views
    
    /// Shows skeleton cells in a collection view
    static func showSkeletonInCollectionView(_ collectionView: UICollectionView, 
                                           cellType: SkeletonCellType, 
                                           numberOfItems: Int = 10) {
        // Store original data source and delegate
        collectionView.tag = 999 // Use tag to identify skeleton state
        
        // Register skeleton cell types
        switch cellType {
        case .coinCell:
            collectionView.register(CoinCellSkeleton.self, forCellWithReuseIdentifier: CoinCellSkeleton.reuseID())
        case .addCoinCell:
            collectionView.register(AddCoinCellSkeleton.self, forCellWithReuseIdentifier: AddCoinCellSkeleton.reuseID())
        }
        
        // Create and set skeleton data source
        let skeletonDataSource = SkeletonCollectionViewDataSource(cellType: cellType, numberOfItems: numberOfItems)
        collectionView.dataSource = skeletonDataSource
        
        // Store skeleton data source to prevent deallocation
        objc_setAssociatedObject(collectionView, &AssociatedKeys.skeletonDataSource, skeletonDataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        collectionView.reloadData()
        
        // Start shimmer animation after a small delay to ensure cells are visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak collectionView] in
            guard let collectionView = collectionView else { return }
            startSkeletonAnimationInCollectionView(collectionView)
        }
    }
    
    /// Dismisses skeleton cells from a collection view
    static func dismissSkeletonFromCollectionView(_ collectionView: UICollectionView) {
        guard collectionView.tag == 999 else { return }
        
        stopSkeletonAnimationInCollectionView(collectionView)
        
        // Remove skeleton data source
        objc_setAssociatedObject(collectionView, &AssociatedKeys.skeletonDataSource, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        collectionView.tag = 0
        // Note: The actual data source should be reset by the calling view controller
    }
    
    /// Checks if a collection view is currently showing skeleton loading
    static func isShowingSkeleton(in collectionView: UICollectionView) -> Bool {
        return collectionView.tag == 999
    }
    
    /// Shows a chart skeleton in a view
    static func showChartSkeleton(in parentView: UIView) -> ChartSkeleton {
        // Remove any existing chart skeleton
        dismissChartSkeleton(from: parentView)
        
        let chartSkeleton = ChartSkeleton()
        chartSkeleton.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(chartSkeleton)
        
        NSLayoutConstraint.activate([
            chartSkeleton.topAnchor.constraint(equalTo: parentView.topAnchor),
            chartSkeleton.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            chartSkeleton.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            chartSkeleton.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
        
        chartSkeleton.startShimmering()
        return chartSkeleton
    }
    
    /// Dismisses chart skeleton from a view
    static func dismissChartSkeleton(from parentView: UIView) {
        for subview in parentView.subviews {
            if let chartSkeleton = subview as? ChartSkeleton {
                chartSkeleton.removeFromParent()
            }
        }
    }
    
    // MARK: - Private Animation Helpers
    
    private static func startSkeletonAnimationInCollectionView(_ collectionView: UICollectionView) {
        for cell in collectionView.visibleCells {
            if let skeletonCell = cell as? CoinCellSkeleton {
                skeletonCell.startShimmering()
            } else if let skeletonCell = cell as? AddCoinCellSkeleton {
                skeletonCell.startShimmering()
            }
        }
    }
    
    private static func stopSkeletonAnimationInCollectionView(_ collectionView: UICollectionView) {
        for cell in collectionView.visibleCells {
            if let skeletonCell = cell as? CoinCellSkeleton {
                skeletonCell.stopShimmering()
            } else if let skeletonCell = cell as? AddCoinCellSkeleton {
                skeletonCell.stopShimmering()
            }
        }
    }
}

// MARK: - Supporting Types

enum SkeletonCellType {
    case coinCell
    case addCoinCell
}

// MARK: - Skeleton Data Source

private class SkeletonCollectionViewDataSource: NSObject, UICollectionViewDataSource {
    
    private let cellType: SkeletonCellType
    private let numberOfItems: Int
    
    init(cellType: SkeletonCellType, numberOfItems: Int) {
        self.cellType = cellType
        self.numberOfItems = numberOfItems
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfItems
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch cellType {
        case .coinCell:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoinCellSkeleton.reuseID(), for: indexPath) as! CoinCellSkeleton
            cell.startShimmering()
            return cell
        case .addCoinCell:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddCoinCellSkeleton.reuseID(), for: indexPath) as! AddCoinCellSkeleton
            cell.startShimmering()
            return cell
        }
    }
}

// MARK: - Associated Object Keys

private struct AssociatedKeys {
    static var skeletonDataSource: UInt8 = 0
}