import UIKit

final class StatsCell: UITableViewCell {

    private let segmentView = SegmentView()
    private let cardView = UIView()
    private let stackView = UIStackView()
    
    private var leftColumn = UIStackView()
    private var rightColumn = UIStackView()

    private var onSegmentChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let headerLabel:UILabel = {
        let label  = UILabel()
        label.text = "Statistics >"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .label
        label.isUserInteractionEnabled = true
        return label
    }()

    private func setupUI() {
        selectionStyle = .none
        contentView.backgroundColor = .clear

        // Adaptive background - white in light mode, gray in dark mode
        cardView.backgroundColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? .secondarySystemBackground 
                : .systemBackground
        }
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4

        contentView.addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        // SegmentView style
        segmentView.translatesAutoresizingMaskIntoConstraints = false
        segmentView.heightAnchor.constraint(equalToConstant: 28).isActive = true
        segmentView.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let segmentWrapper = UIView()
        segmentWrapper.addSubview(segmentView)
        segmentView.trailingAnchor.constraint(equalTo: segmentWrapper.trailingAnchor).isActive = true
        segmentView.topAnchor.constraint(equalTo: segmentWrapper.topAnchor).isActive = true
        segmentView.bottomAnchor.constraint(equalTo: segmentWrapper.bottomAnchor).isActive = true
        segmentView.leadingAnchor.constraint(greaterThanOrEqualTo: segmentWrapper.leadingAnchor).isActive = true

        stackView.axis = .vertical
        stackView.distribution = .fill // Use fill to accommodate different row heights
        stackView.spacing = 8 // Reduced for more compact layout
        
        // Ensure the stackView has enough height for all content
        let minHeightConstraint = stackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        minHeightConstraint.priority = UILayoutPriority(999)
        minHeightConstraint.isActive = true
        
        let headerStack = UIStackView(arrangedSubviews: [headerLabel, segmentWrapper])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        
        let verticalStack = UIStackView(arrangedSubviews: [headerStack, stackView])
        verticalStack.axis = .vertical
        verticalStack.spacing = 16 // Reduced from 24 to save space

        cardView.addSubview(verticalStack)
        verticalStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            verticalStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16), // Reduced from 20
            verticalStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16), // Reduced from 20
            verticalStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16), // Reduced from -20
            verticalStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16) // Reduced from -20
        ])
    }

    func configure(_ stats: [StatItem], selectedRange: String = "24h", onSegmentChange: @escaping (String) -> Void) {
        self.onSegmentChange = onSegmentChange

        // Configure segment view with selected range
        let options = ["24h", "30d", "1y"]
        let selectedIndex = options.firstIndex(of: selectedRange) ?? 0
        
        segmentView.configure(withItems: options)
        segmentView.setSelectedIndex(selectedIndex)
        segmentView.onSelectionChanged = { [weak self] index in
            self?.onSegmentChange?(options[index])
        }

        // Clear previous content
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        leftColumn.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rightColumn.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Separate high/low item from regular stats
        var highLowItem: StatItem?
        var regularStats: [StatItem] = []
        
        for item in stats {
            if item.title == "Low / High" && item.value.contains("|") {
                highLowItem = item
            } else {
                regularStats.append(item)
            }
        }
        
        // Add high/low bar at the top if available
        if let highLowItem = highLowItem {
            let highLowBar = makeHighLowBarRow(for: highLowItem)
            stackView.addArrangedSubview(highLowBar)
        }
        
        // Create 2-column layout for regular stats
        if !regularStats.isEmpty {
            setupTwoColumnLayout(with: regularStats)
        }
    }
    
    private func setupTwoColumnLayout(with stats: [StatItem]) {
        // Reset column configurations
        leftColumn = UIStackView()
        rightColumn = UIStackView()
        
        leftColumn.axis = .vertical
        leftColumn.distribution = .fill
        leftColumn.spacing = 12
        
        rightColumn.axis = .vertical
        rightColumn.distribution = .fill
        rightColumn.spacing = 12
        
        // Distribute stats between columns
        for (index, item) in stats.enumerated() {
            let statRow = makeRegularStatRow(for: item)
            
            if index % 2 == 0 {
                leftColumn.addArrangedSubview(statRow)
            } else {
                rightColumn.addArrangedSubview(statRow)
            }
        }
        
        // Create horizontal container for the two columns
        let columnsContainer = UIStackView(arrangedSubviews: [leftColumn, rightColumn])
        columnsContainer.axis = .horizontal
        columnsContainer.distribution = .fillEqually
        columnsContainer.spacing = 20
        columnsContainer.alignment = .top
        
        // Add columns to main stack
        stackView.addArrangedSubview(columnsContainer)
    }


    private func makeHighLowBarRow(for item: StatItem) -> UIView {
        let values = item.value.components(separatedBy: "|")
        guard values.count >= 2 else {
            // Fallback to regular row if parsing fails
            return makeRegularStatRow(for: item)
        }
        
        let lowValue = values[0]
        let highValue = values[1]
        let currentPrice = values.count > 2 ? Double(values[2]) ?? 0.0 : 0.0
        let isLoading = values.count > 3 ? (values[3] == "true") : false
        
        // Container for the entire high/low section
        let container = HighLowBarContainer()
        container.currentPrice = currentPrice
        container.lowValue = lowValue
        container.highValue = highValue
        container.isLoading = isLoading
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = item.title
        
        // Low value label
        let lowLabel = UILabel()
        lowLabel.font = .boldSystemFont(ofSize: 13)
        lowLabel.textColor = .systemRed
        lowLabel.text = lowValue
        lowLabel.textAlignment = .left
        
        // High value label
        let highLabel = UILabel()
        highLabel.font = .boldSystemFont(ofSize: 13)
        highLabel.textColor = .systemGreen
        highLabel.text = highValue
        highLabel.textAlignment = .right
        
        // Horizontal bar view (background)
        let barView = UIView()
        barView.backgroundColor = .systemGray4
        barView.layer.cornerRadius = 3
        
        // Progress indicator showing current price position
        let progressView = UIView()
        progressView.backgroundColor = .systemGray // Medium gray - good contrast but not harsh
        progressView.layer.cornerRadius = 3
        
        // Loading indicator overlay
        let loadingOverlay = UIView()
        loadingOverlay.backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
        loadingOverlay.layer.cornerRadius = 3
        loadingOverlay.isHidden = !isLoading
        
        // Current price indicator (circle marker)
        let priceIndicator = UIView()
        priceIndicator.backgroundColor = .systemGray // Medium gray - good contrast but not harsh
        priceIndicator.layer.cornerRadius = 6 // Will be 12pt diameter circle
        priceIndicator.layer.borderWidth = 2
        priceIndicator.layer.borderColor = UIColor.systemBackground.cgColor
        priceIndicator.layer.shadowColor = UIColor.black.cgColor
        priceIndicator.layer.shadowOpacity = 0.2
        priceIndicator.layer.shadowOffset = CGSize(width: 0, height: 1)
        priceIndicator.layer.shadowRadius = 2
        
        // Create width constraint for progress view
        let progressWidthConstraint = progressView.widthAnchor.constraint(equalToConstant: 0)
        
        // Store references for positioning
        container.barView = barView
        container.priceIndicator = priceIndicator
        container.progressView = progressView
        container.loadingOverlay = loadingOverlay
        container.progressWidthConstraint = progressWidthConstraint
        
        // Add subviews
        container.addSubview(titleLabel)
        container.addSubview(lowLabel)
        container.addSubview(highLabel)
        container.addSubview(barView)
        barView.addSubview(progressView)
        barView.addSubview(loadingOverlay) // Add loading overlay on top
        container.addSubview(priceIndicator)
        
        // Set up constraints
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        lowLabel.translatesAutoresizingMaskIntoConstraints = false
        highLabel.translatesAutoresizingMaskIntoConstraints = false
        barView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        priceIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Set content compression resistance to prevent layout conflicts
        container.setContentCompressionResistancePriority(UILayoutPriority(750), for: .vertical) // Lower priority
        container.setContentHuggingPriority(UILayoutPriority(1000), for: .vertical) // High hugging to prevent expansion
        titleLabel.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .vertical)
        lowLabel.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .vertical)
        highLabel.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .vertical)
        
        // Calculate current price position as percentage  
        // Parse price strings - handle different formats like "US$105,402.00", "$105,402.00", etc.
        let cleanLowValue = lowValue.replacingOccurrences(of: "US$", with: "").replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let cleanHighValue = highValue.replacingOccurrences(of: "US$", with: "").replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        
        let lowPrice = Double(cleanLowValue) ?? 0.0
        let highPrice = Double(cleanHighValue) ?? 0.0
        let priceRange = highPrice - lowPrice
        let pricePosition = priceRange > 0 ? (currentPrice - lowPrice) / priceRange : 0.5
                let clampedPosition = max(0.0, min(1.0, pricePosition)) // Ensure it's between 0 and 1
        
        container.pricePosition = clampedPosition
        
        NSLayoutConstraint.activate([
            // Title at the top
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            // Bar view below title with flexible height
            barView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            barView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            barView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            barView.heightAnchor.constraint(equalToConstant: 6).withPriority(UILayoutPriority(999)), // Increased height for better visibility
            
            // Progress view shows filled portion up to current price
            progressView.topAnchor.constraint(equalTo: barView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: barView.leadingAnchor),
            progressView.bottomAnchor.constraint(equalTo: barView.bottomAnchor),
            progressWidthConstraint,
            
            // Loading overlay covers the entire bar
            loadingOverlay.topAnchor.constraint(equalTo: barView.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: barView.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: barView.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: barView.bottomAnchor),
            
            // Price indicator circle positioned at current price (will be positioned in layoutSubviews)
            priceIndicator.centerYAnchor.constraint(equalTo: barView.centerYAnchor),
            priceIndicator.widthAnchor.constraint(equalToConstant: 12),
            priceIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            // Low label below bar on the left
            lowLabel.topAnchor.constraint(equalTo: barView.bottomAnchor, constant: 8),
            lowLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            lowLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            // High label below bar on the right
            highLabel.topAnchor.constraint(equalTo: barView.bottomAnchor, constant: 8),
            highLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            highLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            // Prevent labels from overlapping
            lowLabel.trailingAnchor.constraint(lessThanOrEqualTo: highLabel.leadingAnchor, constant: -8)
        ])
        
        // Set initial progress width
        DispatchQueue.main.async {
            if let barView = container.barView, barView.frame.width > 0 {
                let initialWidth = barView.frame.width * CGFloat(clampedPosition)
                progressWidthConstraint.constant = initialWidth
            }
        }
        
        // Add loading animation if needed
        if isLoading {
            container.startLoadingAnimation()
        } else {
            container.stopLoadingAnimation()
        }
        
        // Set flexible height for the container with lower priority
        let minHeightConstraint = container.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        minHeightConstraint.priority = UILayoutPriority(750) // Lower priority to avoid conflicts
        minHeightConstraint.isActive = true
        
        let maxHeightConstraint = container.heightAnchor.constraint(lessThanOrEqualToConstant: 70)
        maxHeightConstraint.priority = UILayoutPriority(800)
        maxHeightConstraint.isActive = true
        
        return container
    }
    
    private func makeRegularStatRow(for item: StatItem) -> UIView {
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = item.title
        titleLabel.numberOfLines = 1
        
        let valueLabel = UILabel()
        valueLabel.font = .boldSystemFont(ofSize: 14)
        valueLabel.textColor = item.valueColor ?? .label
        valueLabel.text = item.value
        valueLabel.numberOfLines = 1
        
        // Stack title above value for compact 2-column layout
        let statStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        statStack.axis = .vertical
        statStack.spacing = 2
        statStack.alignment = .leading
        
        return statStack
    }

}

// Custom container for high/low bar with dynamic price indicator positioning
class HighLowBarContainer: UIView {
    var barView: UIView?
    var priceIndicator: UIView?
    var progressView: UIView?
    var loadingOverlay: UIView?
    var progressWidthConstraint: NSLayoutConstraint?
    var pricePosition: Double = 0.5
    var currentPrice: Double = 0.0
    var lowValue: String = ""
    var highValue: String = ""
    var isLoading: Bool = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Position the price indicator based on the calculated position
        guard let barView = barView, let priceIndicator = priceIndicator else { return }
        
        // Only position if we have valid dimensions
        guard barView.frame.width > 0, priceIndicator.frame.width > 0 else { return }
        
        let barWidth = barView.frame.width
        let indicatorWidth = priceIndicator.frame.width
        let safePosition = max(0.0, min(1.0, pricePosition)) // Ensure position is between 0 and 1
        
        // Calculate X position: bar start + (bar width * position) - (indicator width / 2)
        let targetX = barView.frame.minX + (barWidth * CGFloat(safePosition)) - (indicatorWidth / 2)
        
        // Ensure the indicator stays within the bar bounds
        let minX = barView.frame.minX - (indicatorWidth / 2)
        let maxX = barView.frame.maxX - (indicatorWidth / 2)
        let clampedX = max(minX, min(maxX, targetX))
        
        priceIndicator.frame.origin.x = clampedX
        
        // Update progress view width using constraint
        if let progressWidthConstraint = progressWidthConstraint {
            let newWidth = barWidth * CGFloat(safePosition)
            progressWidthConstraint.constant = newWidth
        }
    }
    
    func startLoadingAnimation() {
        guard let loadingOverlay = loadingOverlay else { return }
        
        // Create a subtle pulsing animation for the loading overlay
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.3
        pulseAnimation.toValue = 0.6
        pulseAnimation.duration = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        loadingOverlay.layer.add(pulseAnimation, forKey: "loadingPulse")
    }
    
    func stopLoadingAnimation() {
        loadingOverlay?.layer.removeAnimation(forKey: "loadingPulse")
        loadingOverlay?.isHidden = true
    }
}

// Extension to make constraint priority setting more convenient
extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
