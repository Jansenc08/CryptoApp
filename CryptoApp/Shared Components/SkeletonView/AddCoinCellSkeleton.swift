import UIKit

final class AddCoinCellSkeleton: UICollectionViewCell {
    
    // MARK: - Properties
    
    private var skeletonViews: [SkeletonView] = []
    
    // Layout components to match AddCoinCell
    private let imageSkeleton = SkeletonView.circleSkeleton(diameter: 40)
    private let symbolSkeleton = SkeletonView.textSkeleton(width: 60, height: 16)
    private let nameSkeleton = SkeletonView.textSkeleton(width: 80, height: 14)
    
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
        // Match AddCoinCell styling
        backgroundColor = UIColor.systemBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).cgColor
        
        contentView.addSubview(imageSkeleton)
        contentView.addSubview(symbolSkeleton)
        contentView.addSubview(nameSkeleton)
        
        // Layout to match AddCoinCell (horizontal layout with image on left, text on right)
        NSLayoutConstraint.activate([
            // Image skeleton positioning (left side, centered vertically)
            imageSkeleton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageSkeleton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            // Symbol skeleton positioning (right of image, top)
            symbolSkeleton.leadingAnchor.constraint(equalTo: imageSkeleton.trailingAnchor, constant: 12),
            symbolSkeleton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            symbolSkeleton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -50), // Leave space for potential checkmark
            
            // Name skeleton positioning (right of image, below symbol)
            nameSkeleton.leadingAnchor.constraint(equalTo: imageSkeleton.trailingAnchor, constant: 12),
            nameSkeleton.topAnchor.constraint(equalTo: symbolSkeleton.bottomAnchor, constant: 2),
            nameSkeleton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -50),
            nameSkeleton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    private func collectSkeletonViews() {
        skeletonViews = [
            imageSkeleton,
            symbolSkeleton,
            nameSkeleton
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
        return "AddCoinCellSkeleton"
    }
} 