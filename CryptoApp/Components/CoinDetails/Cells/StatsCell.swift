import UIKit

final class StatsCell: UITableViewCell {

    private let segmentView = SegmentView()
    private let cardView = UIView()
    private let stackView = UIStackView()
    
    private var leftColumn = UIStackView()
    private var rightColumn = UIStackView()

    private var onSegmentChange: ((String) -> Void)?
     // Avoid reconfiguring the segment control on every update
     private var isSegmentConfigured = false

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
        
        // Configure items only once to prevent layout churn and jank
        if !isSegmentConfigured {
            segmentView.configure(withItems: options)
            isSegmentConfigured = true
        }
        // Update selection silently so we don't trigger callbacks or animations
        segmentView.setSelectedIndexSilently(selectedIndex)
        segmentView.onSelectionChanged = { [weak self] index in
            self?.onSegmentChange?(options[index])
        }

        // Separate high/low item from regular stats
        var highLowItem: StatItem?
        var regularStats: [StatItem] = []
        
        for item in stats {
            if item.title == "Low / High" && (item.value.contains("|") || item.highLowPayload != nil) {
                highLowItem = item
            } else {
                regularStats.append(item)
            }
        }
        
        // Check if we already have a high/low bar and if the new item is loading
        var existingHighLowContainer: HighLowBarContainer?
        if let firstArrangedSubview = stackView.arrangedSubviews.first as? HighLowBarContainer {
            existingHighLowContainer = firstArrangedSubview
        }
        
        // FIXED: If we have a high/low item and it's loading, preserve current state
        if let existingContainer = existingHighLowContainer,
           let highLowItem = highLowItem {
            
            // Check if the new item is in loading state
            let values = highLowItem.value.components(separatedBy: "|")
            let isLoading = values.count > 3 ? (values[3] == "true") : false
            
            if isLoading && values[0] == "LOADING" {
                // Special loading marker - preserve everything, just show loading overlay
                existingContainer.startLoadingAnimation()
            } else if isLoading {
                // Regular loading with data - preserve position but update overlay
                existingContainer.startLoadingAnimation()
            } else {
                // Real data arrived - update with animation
                updateHighLowBarAnimated(container: existingContainer, with: highLowItem)
            }
        } else {
            // Clear previous content and rebuild
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            leftColumn.arrangedSubviews.forEach { $0.removeFromSuperview() }
            rightColumn.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            // Add high/low bar at the top if available (but not for loading markers)
            if let highLowItem = highLowItem {
                let values = highLowItem.value.components(separatedBy: "|")
                let isLoadingMarker = values.count > 1 && values[0] == "LOADING"
                
                if !isLoadingMarker {
                    let highLowBar = makeHighLowBarRow(for: highLowItem)
                    stackView.addArrangedSubview(highLowBar)
                }
            }
        }
        
        // Always rebuild regular stats section
        if !regularStats.isEmpty {
            // Remove only the regular stats section (keep high/low bar)
            if stackView.arrangedSubviews.count > 1 {
                for i in (1..<stackView.arrangedSubviews.count).reversed() {
                    stackView.arrangedSubviews[i].removeFromSuperview()
                }
            }
            setupTwoColumnLayout(with: regularStats)
        }
    }
    
    // ADDED: Method to smoothly update existing high/low bar
    private func updateHighLowBarAnimated(container: HighLowBarContainer, with item: StatItem) {
        // Prefer typed payload
        var lowValue = ""
        var highValue = ""
        var currentPrice: Double = 0.0
        var isLoading = false
        
        if let payload = item.highLowPayload {
            let formatCurrency: (Double) -> String = { value in
                if value >= 1 {
                    let f = NumberFormatter()
                    f.numberStyle = .currency
                    f.currencyCode = "USD"
                    f.minimumFractionDigits = 2
                    f.maximumFractionDigits = 2
                    return f.string(from: NSNumber(value: value)) ?? "$0"
                } else if value > 0 {
                    // Keep standard decimal form; visual micro formatting is applied to the label via attributedText
                    var decimals = 6
                    var v = value
                    while v < 1 && v > 0 && decimals < 10 {
                        v *= 10
                        if v >= 1 { break }
                        decimals += 1
                    }
                    let clamped = max(4, min(decimals, 10))
                    return String(format: "US$%.*f", clamped, value)
                } else {
                    return "US$0.00"
                }
            }
            if let low = payload.low { lowValue = formatCurrency(low) }
            if let high = payload.high { highValue = formatCurrency(high) }
            currentPrice = payload.current ?? 0.0
            isLoading = payload.isLoading
        } else {
            let values = item.value.components(separatedBy: "|")
            guard values.count >= 2 else { return }
            lowValue = values[0]
            highValue = values[1]
            currentPrice = values.count > 2 ? Double(values[2]) ?? 0.0 : 0.0
            isLoading = values.count > 3 ? (values[3] == "true") : false
        }
        

        
        // FIXED: Better price parsing for formatted currency strings
        func parsePrice(from string: String) -> Double {
            // Remove currency symbols, commas, and whitespace
            // IMPORTANT: Remove US$ BEFORE $ to avoid leaving "US" in the string
            let cleanString = string
                .replacingOccurrences(of: "US$", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "USD", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Double(cleanString) ?? 0.0
        }
        
        let lowPrice = item.highLowPayload?.low ?? parsePrice(from: lowValue)
        let highPrice = item.highLowPayload?.high ?? parsePrice(from: highValue)
        
        // Calculate new position with enhanced precision for high-value coins
        let priceRange = highPrice - lowPrice
        let clampedPosition: Double
        
        if priceRange > 0 && priceRange.isFinite && currentPrice.isFinite {
            let rawPosition = (currentPrice - lowPrice) / priceRange
            // Ensure we get a valid position, especially for high-precision calculations
            if rawPosition.isFinite {
                clampedPosition = min(max(rawPosition, 0.0), 1.0)
            } else {
                clampedPosition = 0.5 // Safe fallback
            }
        } else {
            clampedPosition = 0.5
        }
        
        // Update the low and high labels (preserve micro formatting)
        for subview in container.subviews {
            guard let label = subview as? UILabel else { continue }
            if label.textColor == .systemRed {
                // Low label
                if lowPrice > 0 && lowPrice < 0.01 {
                    label.attributedText = MicroPriceFormatter.formatUSD(lowPrice, font: label.font)
                } else {
                    label.attributedText = nil
                    label.text = lowValue
                }
            } else if label.textColor == .systemGreen {
                // High label
                if highPrice > 0 && highPrice < 0.01 {
                    label.attributedText = MicroPriceFormatter.formatUSD(highPrice, font: label.font)
                } else {
                    label.attributedText = nil
                    label.text = highValue
                }
            }
        }
        
        // Constraint-driven progress and indicator

        container.animateToPosition(clampedPosition, currentPrice: currentPrice, lowValue: lowValue, highValue: highValue, isLoading: isLoading)
        
        // Update loading state
        container.stopLoadingAnimation() // Real data arrived, stop loading
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
        // Prefer typed payload if available (no string parsing). Fallback to legacy string format.
        var lowValue = ""
        var highValue = ""
        var currentPrice: Double = 0.0
        var isLoading = false
        
        if let payload = item.highLowPayload {
            // Format labels; keep numbers for bar math
            let formatCurrency: (Double) -> String = { value in
                if value >= 1 {
                    let f = NumberFormatter()
                    f.numberStyle = .currency
                    f.currencyCode = "USD"
                    f.minimumFractionDigits = 2
                    f.maximumFractionDigits = 2
                    return f.string(from: NSNumber(value: value)) ?? "$0"
                } else if value > 0 {
                    var decimals = 6
                    var v = value
                    while v < 1 && v > 0 && decimals < 10 {
                        v *= 10
                        if v >= 1 { break }
                        decimals += 1
                    }
                    let clamped = max(4, min(decimals, 10))
                    return String(format: "US$%.*f", clamped, value)
                } else {
                    return "US$0.00"
                }
            }
            if let low = payload.low { lowValue = formatCurrency(low) }
            if let high = payload.high { highValue = formatCurrency(high) }
            currentPrice = payload.current ?? 0.0
            isLoading = payload.isLoading
        } else {
            let values = item.value.components(separatedBy: "|")
            guard values.count >= 2 else { return makeRegularStatRow(for: item) }
            lowValue = values[0]
            highValue = values[1]
            currentPrice = values.count > 2 ? Double(values[2]) ?? 0.0 : 0.0
            isLoading = values.count > 3 ? (values[3] == "true") : false
        }
        
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
        
        // Low value label (supports micro-price formatting)
        let lowLabel = UILabel()
        lowLabel.font = .boldSystemFont(ofSize: 13)
        lowLabel.textColor = .systemRed
        lowLabel.textAlignment = .left
        if let lowDouble = item.highLowPayload?.low, lowDouble > 0, lowDouble < 0.01 {
            lowLabel.attributedText = MicroPriceFormatter.formatUSD(lowDouble, font: lowLabel.font)
        } else {
            lowLabel.text = lowValue
        }
        
        // High value label (supports micro-price formatting)
        let highLabel = UILabel()
        highLabel.font = .boldSystemFont(ofSize: 13)
        highLabel.textColor = .systemGreen
        highLabel.textAlignment = .right
        if let highDouble = item.highLowPayload?.high, highDouble > 0, highDouble < 0.01 {
            highLabel.attributedText = MicroPriceFormatter.formatUSD(highDouble, font: highLabel.font)
        } else {
            highLabel.text = highValue
        }
        
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
        
        // Store references for positioning
        // Create width constraint for progress view
        let progressWidthConstraint = progressView.widthAnchor.constraint(equalToConstant: 0)

        // Store references for positioning
        container.barView = barView
        container.priceIndicator = priceIndicator
        container.progressView = progressView
        container.loadingOverlay = loadingOverlay
        container.progressWidthConstraint = progressWidthConstraint
        
        // Add subviews
        container.addSubviews(titleLabel, lowLabel, highLabel, barView, priceIndicator)
        barView.addSubviews(progressView, loadingOverlay) // Add loading overlay on top
        
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
        
        func parsePrice(from string: String) -> Double {
            // Remove currency symbols, commas, and whitespace
            let cleanString = string
                .replacingOccurrences(of: "US$", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "USD", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Double(cleanString) ?? 0.0
        }
        
        let lowPrice = item.highLowPayload?.low ?? parsePrice(from: lowValue)
        let highPrice = item.highLowPayload?.high ?? parsePrice(from: highValue)
        let priceRange = highPrice - lowPrice
        
        let pricePosition: Double
        if priceRange > 0 && priceRange.isFinite {
            pricePosition = (currentPrice - lowPrice) / priceRange
        } else {
            pricePosition = 0.5
        }
        
        let clampedPosition = max(0.0, min(1.0, pricePosition))
        

        
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
            
            // Price indicator circle follows bar (we'll pin via centerX to barView; moved in layout)
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
        
        // Link indicator X to progressView trailing edge
        let indicatorCenterX = priceIndicator.centerXAnchor.constraint(equalTo: progressView.trailingAnchor)
        indicatorCenterX.isActive = true
        container.priceIndicatorCenterXConstraint = indicatorCenterX

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
    // Keep the indicator tied to progress trailing for layout-driven updates
    var priceIndicatorCenterXConstraint: NSLayoutConstraint?
    var pricePosition: Double = 0.5
    var currentPrice: Double = 0.0
    var lowValue: String = ""
    var highValue: String = ""
    var isLoading: Bool = false
    
    // ADDED: Animation properties for smooth transitions
    private var targetPosition: Double = 0.5
    private var isAnimating: Bool = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure we have necessary views
        guard let barView = barView else { return }
        
        // Update progress view width using constraint (indicator follows via constraint linkage)
        if let progressWidthConstraint = progressWidthConstraint {
            let barWidth = barView.frame.width
            if barWidth > 0 {
                let safePosition = max(0.0, min(1.0, pricePosition))
                progressWidthConstraint.constant = barWidth * CGFloat(safePosition)
            }
        }
    }
    
    // ADDED: Smooth animation method for position changes
    func animateToPosition(_ newPosition: Double, currentPrice: Double, lowValue: String, highValue: String, isLoading: Bool) {
        // Update the data properties
        self.currentPrice = currentPrice
        self.lowValue = lowValue
        self.highValue = highValue
        self.isLoading = isLoading
        
        // Calculate the new target position
        targetPosition = max(0.0, min(1.0, newPosition))
        
        // Always update position (remove the threshold check that was preventing updates)
        pricePosition = targetPosition
        
        // Always restart the animation to the newest target for snappy updates
        layer.removeAllAnimations()
        isAnimating = true
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState],
            animations: { [weak self] in
                guard let self = self else { return }
                if let progressWidthConstraint = self.progressWidthConstraint,
                   let barView = self.barView,
                   barView.frame.width > 0 {
                    let newWidth = barView.frame.width * CGFloat(self.targetPosition)
                    progressWidthConstraint.constant = newWidth
                    // Because the indicator is constraint-linked to progress trailing,
                    // layoutIfNeeded will move them together without drift.
                    self.layoutIfNeeded()
                }
            },
            completion: { [weak self] _ in
                self?.isAnimating = false
            }
        )
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
