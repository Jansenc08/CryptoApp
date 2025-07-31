import UIKit

final class CoinCellSkeleton: UICollectionViewCell {
    
    // MARK: - Properties
    
    private var skeletonViews: [SkeletonView] = []
    
    // Layout components to match CoinCell
    private let rankSkeleton = SkeletonView.textSkeleton(width: 20, height: 12)
    private let imageSkeleton = SkeletonView.circleSkeleton(diameter: 32)
    private let nameSkeleton = SkeletonView.textSkeleton(width: 80, height: 14)
    private let marketSkeleton = SkeletonView.textSkeleton(width: 60, height: 12)
    private let priceSkeleton = SkeletonView.textSkeleton(width: 70, height: 14)
    private let sparklineSkeleton = SkeletonView.rectangleSkeleton(width: 60, height: 20, cornerRadius: 2)
    private let percentSkeleton = SkeletonView.textSkeleton(width: 50, height: 12)
    
    // Stack views to match CoinCell layout
    private lazy var nameStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [nameSkeleton, marketSkeleton])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        return stack
    }()
    
    private lazy var leftStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [rankSkeleton, imageSkeleton, nameStack])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.distribution = .fill
        return stack
    }()
    
    private lazy var sparklineAndPercentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [sparklineSkeleton, percentSkeleton])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        return stack
    }()
    
    private lazy var rightStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [priceSkeleton, sparklineAndPercentStack])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 16
        stack.distribution = .fill
        return stack
    }()
    
    private lazy var mainStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [leftStack, rightStack])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        collectSkeletonViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        collectSkeletonViews()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.addSubview(mainStack)
        
        // Match CoinCell constraints exactly
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            // Fixed sizes to match CoinCell
            rankSkeleton.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            nameSkeleton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            priceSkeleton.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            sparklineAndPercentStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        
        // Set content hugging priorities to match CoinCell
        rankSkeleton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageSkeleton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        sparklineSkeleton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        sparklineAndPercentStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }
    
    private func collectSkeletonViews() {
        skeletonViews = [
            rankSkeleton,
            imageSkeleton,
            nameSkeleton,
            marketSkeleton,
            priceSkeleton,
            sparklineSkeleton,
            percentSkeleton
        ]
    }
    
    // MARK: - Public Methods
    
    func startShimmering() {
        skeletonViews.forEach { $0.startShimmering() }
    }
    
    func stopShimmering() {
        skeletonViews.forEach { $0.stopShimmering() }
    }
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stopShimmering()
    }
    
    static var reuseID: String {
        return "CoinCellSkeleton"
    }
} 