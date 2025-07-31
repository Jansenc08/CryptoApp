import UIKit

final class ChartSkeleton: UIView {
    
    // MARK: - Properties
    
    private var skeletonViews: [SkeletonView] = []
    private let containerView = UIView()
    
    // Chart skeleton components
    private let chartAreaSkeleton = SkeletonView.rectangleSkeleton(width: 0, height: 0, cornerRadius: 8)
    private let yAxisLabelsSkeleton1 = SkeletonView.textSkeleton(width: 40, height: 12)
    private let yAxisLabelsSkeleton2 = SkeletonView.textSkeleton(width: 40, height: 12)
    private let yAxisLabelsSkeleton3 = SkeletonView.textSkeleton(width: 40, height: 12)
    private let xAxisLabelsSkeleton1 = SkeletonView.textSkeleton(width: 30, height: 12)
    private let xAxisLabelsSkeleton2 = SkeletonView.textSkeleton(width: 30, height: 12)
    private let xAxisLabelsSkeleton3 = SkeletonView.textSkeleton(width: 30, height: 12)
    
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
        backgroundColor = .systemBackground
        
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add all skeleton components
        containerView.addSubview(chartAreaSkeleton)
        containerView.addSubview(yAxisLabelsSkeleton1)
        containerView.addSubview(yAxisLabelsSkeleton2)
        containerView.addSubview(yAxisLabelsSkeleton3)
        containerView.addSubview(xAxisLabelsSkeleton1)
        containerView.addSubview(xAxisLabelsSkeleton2)
        containerView.addSubview(xAxisLabelsSkeleton3)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container fills the view
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            // Chart area skeleton (main chart area) - adjusted for right-side Y-axis
            chartAreaSkeleton.topAnchor.constraint(equalTo: containerView.topAnchor),
            chartAreaSkeleton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            chartAreaSkeleton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -50),
            chartAreaSkeleton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -30),
            
            // Y-axis labels (RIGHT side - matching your chart layout)
            yAxisLabelsSkeleton1.topAnchor.constraint(equalTo: chartAreaSkeleton.topAnchor),
            yAxisLabelsSkeleton1.leadingAnchor.constraint(equalTo: chartAreaSkeleton.trailingAnchor, constant: 8),
            
            yAxisLabelsSkeleton2.centerYAnchor.constraint(equalTo: chartAreaSkeleton.centerYAnchor),
            yAxisLabelsSkeleton2.leadingAnchor.constraint(equalTo: chartAreaSkeleton.trailingAnchor, constant: 8),
            
            yAxisLabelsSkeleton3.bottomAnchor.constraint(equalTo: chartAreaSkeleton.bottomAnchor),
            yAxisLabelsSkeleton3.leadingAnchor.constraint(equalTo: chartAreaSkeleton.trailingAnchor, constant: 8),
            
            // X-axis labels (bottom)
            xAxisLabelsSkeleton1.topAnchor.constraint(equalTo: chartAreaSkeleton.bottomAnchor, constant: 8),
            xAxisLabelsSkeleton1.leadingAnchor.constraint(equalTo: chartAreaSkeleton.leadingAnchor),
            
            xAxisLabelsSkeleton2.topAnchor.constraint(equalTo: chartAreaSkeleton.bottomAnchor, constant: 8),
            xAxisLabelsSkeleton2.centerXAnchor.constraint(equalTo: chartAreaSkeleton.centerXAnchor),
            
            xAxisLabelsSkeleton3.topAnchor.constraint(equalTo: chartAreaSkeleton.bottomAnchor, constant: 8),
            xAxisLabelsSkeleton3.trailingAnchor.constraint(equalTo: chartAreaSkeleton.trailingAnchor)
        ])
    }
    
    private func collectSkeletonViews() {
        skeletonViews = [
            chartAreaSkeleton,
            yAxisLabelsSkeleton1,
            yAxisLabelsSkeleton2,
            yAxisLabelsSkeleton3,
            xAxisLabelsSkeleton1,
            xAxisLabelsSkeleton2,
            xAxisLabelsSkeleton3
        ]
    }
    
    // MARK: - Public Methods
    
    func startShimmering() {
        skeletonViews.forEach { $0.startShimmering() }
    }
    
    func stopShimmering() {
        skeletonViews.forEach { $0.stopShimmering() }
    }
    
    func removeFromParent() {
        stopShimmering()
        removeFromSuperview()
    }
} 