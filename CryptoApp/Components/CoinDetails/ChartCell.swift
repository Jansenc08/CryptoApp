import UIKit

final class ChartCell: UITableViewCell {
    private let lineChartView = ChartView()
    private let candlestickChartView = CandlestickChartView()
    private let containerView = UIView()
    
    // Loading and error state views
    private let loadingView = UIView()
    private let errorView = UIView()
    private let errorLabel = UILabel()
    private let retryButton = RetryButton()
    private let errorStackView = UIStackView()
    
    private var currentChartType: ChartType = .line
    private var currentPoints: [Double] = []
    private var currentOHLCData: [OHLCData] = []
    private var currentRange: String = "24h"
    
    // Chart state tracking
    private enum ChartState {
        case loading
        case data
        case error(RetryErrorInfo)
        case nonRetryableError(String)
    }
    
    private var currentState: ChartState = .loading
    private var isSetupComplete: Bool = false
    
    // Retry callback
    var onRetryRequested: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset to loading state on reuse to prevent flashing
        currentState = .loading
        updateViewsForState()
        
        // Reset retry button to prevent constraint conflicts
        retryButton.resetToNormalMode()
        
        // Clear any cached data
        currentPoints = []
        currentOHLCData = []
        currentRange = "24h"
        onRetryRequested = nil
        
        // Note: Don't reset isSetupComplete as UI setup should only happen once
    }
    
    private func setupUI() {
        guard !isSetupComplete else { return }
        
        // Add container to content view
        contentView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        
        // Add both chart views to container
        containerView.addSubviews(lineChartView, candlestickChartView)
        
        lineChartView.translatesAutoresizingMaskIntoConstraints = false
        candlestickChartView.translatesAutoresizingMaskIntoConstraints = false
        
        // Both charts fill the container
        NSLayoutConstraint.activate([
            lineChartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            lineChartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            lineChartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lineChartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            candlestickChartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            candlestickChartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            candlestickChartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            candlestickChartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // Setup loading view
        setupLoadingView()
        
        // Setup error view
        setupErrorView()
        
        // Initially show line chart
        showChart(type: .line, animated: false)
        
        // Start in loading state to show skeleton immediately
        updateViewsForState()
        
        isSetupComplete = true
    }
    
    private func setupLoadingView() {
        // Loading container for skeleton screens
        containerView.addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.backgroundColor = .systemBackground
        loadingView.isHidden = true
        
        // Layout loading view
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            loadingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
    }
    
    private func setupErrorView() {
        // Error container
        containerView.addSubview(errorView)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = .systemBackground
        errorView.isHidden = true
        
        // Error label
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 16, weight: .medium)
        errorLabel.textColor = .secondaryLabel
        errorLabel.numberOfLines = 0
        // Note: No default text - will be set when actual errors occur
        
        // Retry button
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.enableCompactMode() // Make it smaller for chart area
        retryButton.setRetryAction { [weak self] in
            self?.handleRetryTapped()
        }
        
        // Error stack view
        errorStackView.axis = .vertical
        errorStackView.alignment = .center
        errorStackView.spacing = 20  // More spacing for better touch area
        errorStackView.translatesAutoresizingMaskIntoConstraints = false
        
        errorStackView.addArrangedSubview(errorLabel)
        errorStackView.addArrangedSubview(retryButton)
        errorView.addSubview(errorStackView)
        
        // Layout error view
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: containerView.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            errorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            errorStackView.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            errorStackView.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            errorStackView.leadingAnchor.constraint(greaterThanOrEqualTo: errorView.leadingAnchor, constant: 20),
            errorStackView.trailingAnchor.constraint(lessThanOrEqualTo: errorView.trailingAnchor, constant: -20)
        ])
    }
    
    private func handleRetryTapped() {
        AppLogger.ui("Chart retry button tapped")
        retryButton.showLoading()
        onRetryRequested?()
        
        // Hide loading state after a short delay (actual loading will be managed by parent)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.retryButton.hideLoading()
        }
    }
    

    
    private func showChart(type: ChartType, animated: Bool = true) {
        currentChartType = type
        
        let showLineChart = (type == .line)
        
        if animated {
            UIView.transition(with: containerView, duration: 0.3, options: .transitionCrossDissolve) {
                self.lineChartView.isHidden = !showLineChart
                self.candlestickChartView.isHidden = showLineChart
            }
        } else {
            lineChartView.isHidden = !showLineChart
            candlestickChartView.isHidden = showLineChart
        }
    }
    
    private func updateViewsForState() {
        switch currentState {
        case .loading:
            // Show chart skeleton, hide charts and error
            loadingView.isHidden = false
            errorView.isHidden = true
            lineChartView.isHidden = true
            candlestickChartView.isHidden = true
            // Show chart skeleton instead of activity indicator
            _ = SkeletonLoadingManager.showChartSkeleton(in: loadingView)
            print("📊 Chart cell showing skeleton loading state")
            
        case .data:
            // Show appropriate chart based on type, hide loading and error
            SkeletonLoadingManager.dismissChartSkeleton(from: loadingView)
            loadingView.isHidden = true
            errorView.isHidden = true
            
            let showLineChart = (currentChartType == .line)
            lineChartView.isHidden = !showLineChart
            candlestickChartView.isHidden = showLineChart
            print("📊 Chart cell showing data state for \(currentChartType.rawValue) chart")
            
        case .error(let retryInfo):
            // Show retryable error with retry button
            SkeletonLoadingManager.dismissChartSkeleton(from: loadingView)
            loadingView.isHidden = true
            errorView.isHidden = false
            lineChartView.isHidden = true
            candlestickChartView.isHidden = true
            errorLabel.text = retryInfo.message
            retryButton.isHidden = false
            retryButton.setTitle("Retry")
            print("📊 Chart cell showing retryable error: \(retryInfo.message)")
            
        case .nonRetryableError(let message):
            // Show non-retryable error without retry button
            SkeletonLoadingManager.dismissChartSkeleton(from: loadingView)
            loadingView.isHidden = true
            errorView.isHidden = false
            lineChartView.isHidden = true
            candlestickChartView.isHidden = true
            errorLabel.text = message
            retryButton.isHidden = true
            print("📊 Chart cell showing non-retryable error: \(message)")
        }
    }

    // Configure with line chart data
    func configure(points: [Double], range: String) {
        self.currentPoints = points
        self.currentRange = range
        
        if !points.isEmpty {
            // Only update to data state if not currently loading
            // This prevents interrupting the loading skeleton during cell reuse
            if case .loading = currentState {
                // Keep loading state - will be updated by view controller bindings
                lineChartView.update(points, range: range)
            } else {
                currentState = .data
                lineChartView.update(points, range: range)
                updateViewsForState()
            }
        }
    }
    
    // Configure with OHLC data for candlestick chart
    func configure(ohlcData: [OHLCData], range: String) {
        self.currentOHLCData = ohlcData
        self.currentRange = range
        
        if !ohlcData.isEmpty {
            // Only update to data state if not currently loading
            // This prevents interrupting the loading skeleton during cell reuse
            if case .loading = currentState {
                // Keep loading state - will be updated by view controller bindings
                candlestickChartView.update(ohlcData, range: range)
            } else {
                currentState = .data
                candlestickChartView.update(ohlcData, range: range)
                updateViewsForState()
            }
        }
    }
    
    // Switch chart type
    func switchChartType(to chartType: ChartType) {
        guard chartType != currentChartType else { return }
        currentChartType = chartType
        
        // Only update views if we're in data state
        if case .data = currentState {
            updateViewsForState()
        }
    }
    
    // Update chart data without recreation
    func updateChartData(points: [Double]? = nil, ohlcData: [OHLCData]? = nil, range: String) {
        self.currentRange = range
        
        var hasData = false
        
        if let points = points {
            self.currentPoints = points
            if !points.isEmpty {
                lineChartView.update(points, range: range)
                hasData = true
            }
        }
        
        if let ohlcData = ohlcData {
            self.currentOHLCData = ohlcData
            if !ohlcData.isEmpty {
                candlestickChartView.update(ohlcData, range: range)
                hasData = true
            } else {
                // FIXED: Only clear and show loading if we're actually in candlestick mode and expecting data
                if currentChartType == .candlestick && points == nil {
                    AppLogger.chart("Empty OHLC data - clearing candlestick chart for \(range)")
                    candlestickChartView.clear() // Clear the candlestick display
                    currentState = .loading // Show loading when candlestick data is cleared
                    updateViewsForState()
                    return
                }
            }
        }
        
        // FIXED: Only update state if we actually have data or if we're not in a loading scenario
        if hasData {
            currentState = .data
            updateViewsForState()
        } else if ohlcData != nil && ohlcData!.isEmpty && currentChartType == .line {
            // If we received empty OHLC data but we're in line mode, don't show loading
            AppLogger.chart("Ignoring empty OHLC data - in line chart mode")
        }
        
        AppLogger.chart("Updated chart: \(currentChartType) | Range: \(range)")
    }
    
    // New method to handle loading state
    func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            currentState = .loading
            updateViewsForState()
        }
        // Note: We don't set .data state here since that should only happen when we actually receive data
    }
    

    
    // New methods to handle error states
    func showErrorState(_ message: String) {
        currentState = .nonRetryableError(message)
        updateViewsForState()
    }
    
    func showRetryableError(_ retryInfo: RetryErrorInfo) {
        currentState = .error(retryInfo)
        updateViewsForState()
    }
    
    func showNonRetryableError(_ message: String) {
        currentState = .nonRetryableError(message)
        updateViewsForState()
    }
    
    // Allows setting a scroll callback for line chart
    var onScrollToEdge: ((ChartView.ScrollDirection) -> Void)? {
        get { lineChartView.onScrollToEdge }
        set { 
            lineChartView.onScrollToEdge = newValue
            // Map the callback for candlestick chart too
            candlestickChartView.onScrollToEdge = { direction in
                switch direction {
                case .left:
                    newValue?(.left)
                case .right:
                    newValue?(.right)
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Dark Mode Support
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Ensure container background updates with appearance changes
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.backgroundColor = .clear
            contentView.backgroundColor = .clear
            backgroundColor = .clear
            loadingView.backgroundColor = .systemBackground
            errorView.backgroundColor = .systemBackground
        }
    }
}

// MARK: - Chart Settings Support

extension ChartCell {
    
    func updateLineThickness(_ thickness: CGFloat) {
        lineChartView.updateLineThickness(thickness)
        candlestickChartView.updateLineThickness(thickness)
    }
    
    func toggleGridLines(_ enabled: Bool) {
        lineChartView.toggleGridLines(enabled)
        candlestickChartView.toggleGridLines(enabled)
    }
    
    func togglePriceLabels(_ enabled: Bool) {
        lineChartView.togglePriceLabels(enabled)
        candlestickChartView.togglePriceLabels(enabled)
    }
    
    func toggleAutoScale(_ enabled: Bool) {
        lineChartView.toggleAutoScale(enabled)
        candlestickChartView.toggleAutoScale(enabled)
    }
    
    func applyColorTheme(_ theme: ChartColorTheme) {
        lineChartView.applyColorTheme(theme)
        candlestickChartView.applyColorTheme(theme)
    }
    
    func setAnimationSpeed(_ speed: Double) {
        lineChartView.setAnimationSpeed(speed)
        candlestickChartView.setAnimationSpeed(speed)
    }
}
