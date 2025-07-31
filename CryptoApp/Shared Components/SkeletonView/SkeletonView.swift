import UIKit

final class SkeletonView: UIView {
    
    // MARK: - Properties
    
    private let gradientLayer = CAGradientLayer()
    private var isAnimating = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSkeleton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSkeleton()
    }
    
    // MARK: - Setup
    
    private func setupSkeleton() {
        backgroundColor = UIColor.systemGray5
        layer.cornerRadius = 4
        
        // Setup gradient layer for shimmer effect
        gradientLayer.colors = [
            UIColor.systemGray5.cgColor,
            UIColor.systemGray4.cgColor,
            UIColor.systemGray5.cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(gradientLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    // MARK: - Animation
    
    func startShimmering() {
        guard !isAnimating else { return }
        isAnimating = true
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "shimmer")
    }
    
    func stopShimmering() {
        isAnimating = false
        gradientLayer.removeAnimation(forKey: "shimmer")
    }
}

// MARK: - Convenience Factory Methods

extension SkeletonView {
    
    /// Creates a skeleton view that mimics a text label
    static func textSkeleton(width: CGFloat, height: CGFloat = 16) -> SkeletonView {
        let skeleton = SkeletonView()
        skeleton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            skeleton.widthAnchor.constraint(equalToConstant: width),
            skeleton.heightAnchor.constraint(equalToConstant: height)
        ])
        return skeleton
    }
    
    /// Creates a skeleton view that mimics a circular image
    static func circleSkeleton(diameter: CGFloat) -> SkeletonView {
        let skeleton = SkeletonView()
        skeleton.translatesAutoresizingMaskIntoConstraints = false
        skeleton.layer.cornerRadius = diameter / 2
        NSLayoutConstraint.activate([
            skeleton.widthAnchor.constraint(equalToConstant: diameter),
            skeleton.heightAnchor.constraint(equalToConstant: diameter)
        ])
        return skeleton
    }
    
    /// Creates a skeleton view that mimics a rectangular area
    static func rectangleSkeleton(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 4) -> SkeletonView {
        let skeleton = SkeletonView()
        skeleton.translatesAutoresizingMaskIntoConstraints = false
        skeleton.layer.cornerRadius = cornerRadius
        NSLayoutConstraint.activate([
            skeleton.widthAnchor.constraint(equalToConstant: width),
            skeleton.heightAnchor.constraint(equalToConstant: height)
        ])
        return skeleton
    }
    
    /// Creates a skeleton view that will be sized by its container constraints
    static func resizableSkeleton(cornerRadius: CGFloat = 4) -> SkeletonView {
        let skeleton = SkeletonView()
        skeleton.translatesAutoresizingMaskIntoConstraints = false
        skeleton.layer.cornerRadius = cornerRadius
        return skeleton
    }
}

// MARK: - Container View for Multiple Skeletons

final class SkeletonContainerView: UIView {
    
    private var skeletonViews: [SkeletonView] = []
    
    func addSkeletonViews(_ views: [SkeletonView]) {
        skeletonViews.append(contentsOf: views)
        views.forEach { addSubview($0) }
    }
    
    func startShimmering() {
        skeletonViews.forEach { $0.startShimmering() }
    }
    
    func stopShimmering() {
        skeletonViews.forEach { $0.stopShimmering() }
    }
    
    func removeAllSkeletons() {
        skeletonViews.forEach { $0.removeFromSuperview() }
        skeletonViews.removeAll()
    }
} 