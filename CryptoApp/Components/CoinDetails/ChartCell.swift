import UIKit

final class ChartCell: UITableViewCell {
    private let lineChartView = ChartView()
    private let candlestickChartView = CandlestickChartView()
    private let volumeChartView = VolumeChartView()
    private let containerView = UIView()
    private let chartsStackView = UIStackView()
    
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
    
    // Technical Indicators Pending Settings
    private var pendingIndicatorSettings: TechnicalIndicators.IndicatorSettings?
    private var pendingIndicatorTheme: ChartColorTheme?
    
    // Volume Settings
    private var showVolume: Bool = false

    
    // Chart state tracking
    private enum ChartState: Equatable {
        case ready          // OPTIMAL: Ready to receive data - no loading shown yet
        case loading
        case data
        case error(RetryErrorInfo)
        case nonRetryableError(String)
        
        static func == (lhs: ChartState, rhs: ChartState) -> Bool {
            switch (lhs, rhs) {
            case (.ready, .ready), (.loading, .loading), (.data, .data):
                return true
            case (.error(_), .error(_)), (.nonRetryableError(_), .nonRetryableError(_)):
                return true
            default:
                return false
            }
        }
    }
    
    private var currentState: ChartState = .ready  // Start ready - follow SharedCoinDataManager pattern
    private var isSetupComplete: Bool = false
    
    // Retry callback
    var onRetryRequested: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset to ready state - prepared to receive new data
        currentState = .ready
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
        
        // Setup stack view for price chart and volume chart
        chartsStackView.axis = .vertical
        chartsStackView.spacing = 4  // Reduced spacing for seamless integration
        chartsStackView.distribution = .fill
        chartsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(chartsStackView)
        NSLayoutConstraint.activate([
            chartsStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            chartsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            chartsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            chartsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // Create main chart container (will hold either line or candlestick chart)
        let mainChartContainer = UIView()
        mainChartContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Add both price chart views to main chart container (only one will be visible at a time)
        mainChartContainer.addSubviews(lineChartView, candlestickChartView)
        
        lineChartView.translatesAutoresizingMaskIntoConstraints = false
        candlestickChartView.translatesAutoresizingMaskIntoConstraints = false
        volumeChartView.translatesAutoresizingMaskIntoConstraints = false
        
        // Both price charts fill the main chart container
        NSLayoutConstraint.activate([
            lineChartView.topAnchor.constraint(equalTo: mainChartContainer.topAnchor),
            lineChartView.bottomAnchor.constraint(equalTo: mainChartContainer.bottomAnchor),
            lineChartView.leadingAnchor.constraint(equalTo: mainChartContainer.leadingAnchor),
            lineChartView.trailingAnchor.constraint(equalTo: mainChartContainer.trailingAnchor),
            
            candlestickChartView.topAnchor.constraint(equalTo: mainChartContainer.topAnchor),
            candlestickChartView.bottomAnchor.constraint(equalTo: mainChartContainer.bottomAnchor),
            candlestickChartView.leadingAnchor.constraint(equalTo: mainChartContainer.leadingAnchor),
            candlestickChartView.trailingAnchor.constraint(equalTo: mainChartContainer.trailingAnchor)
        ])
        
        // Add main chart container and volume chart to stack view
        chartsStackView.addArrangedSubview(mainChartContainer)
        chartsStackView.addArrangedSubview(volumeChartView)
        
        // Set fixed height constraints to prevent chart size changes when volume is toggled
        NSLayoutConstraint.activate([
            mainChartContainer.heightAnchor.constraint(equalToConstant: 250),
            volumeChartView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        // Initially hide volume chart
        volumeChartView.isHidden = true
        
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
        // Chart retry button tapped
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
        case .ready:
            // OPTIMAL: Show chart area ready for data - like SharedCoinDataManager pattern
            loadingView.isHidden = true
            errorView.isHidden = true
            // Show chart views but they'll be empty until data arrives
            let showLineChart = (currentChartType == .line)
            lineChartView.isHidden = !showLineChart
            candlestickChartView.isHidden = showLineChart
            // Chart cell ready for data
            
        case .loading:
            // Show chart skeleton, hide charts and error
            loadingView.isHidden = false
            errorView.isHidden = true
            lineChartView.isHidden = true
            candlestickChartView.isHidden = true
            // Show chart skeleton instead of activity indicator
            _ = SkeletonLoadingManager.showChartSkeleton(in: loadingView)
            // Show skeleton loading state
            
        case .data:
            // Show appropriate chart based on type, hide loading and error
            SkeletonLoadingManager.dismissChartSkeleton(from: loadingView)
            loadingView.isHidden = true
            errorView.isHidden = true
            
            let showLineChart = (currentChartType == .line)
            lineChartView.isHidden = !showLineChart
            candlestickChartView.isHidden = showLineChart
            // Show data state
            
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
            // Show retryable error state
            
        case .nonRetryableError(let message):
            // Show non-retryable error without retry button
            SkeletonLoadingManager.dismissChartSkeleton(from: loadingView)
            loadingView.isHidden = true
            errorView.isHidden = false
            lineChartView.isHidden = true
            candlestickChartView.isHidden = true
            errorLabel.text = message
            retryButton.isHidden = true
            // Show non-retryable error state
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
                reapplyTechnicalIndicators()
            } else {
                currentState = .data
                lineChartView.update(points, range: range)
                reapplyTechnicalIndicators()
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
                reapplyTechnicalIndicators()
                // Update volume chart with new OHLC data
                if showVolume {
                    // Update volume chart with new OHLC data
                    updateVolumeData()
                }
            } else {
                currentState = .data
                candlestickChartView.update(ohlcData, range: range)
                reapplyTechnicalIndicators()
                updateViewsForState()
                // Update volume chart with new OHLC data
                if showVolume {
                    updateVolumeData()
                }
            }
        }
    }
    
    // Switch chart type
    func switchChartType(to chartType: ChartType) {
        guard chartType != currentChartType else { return }
        
        let previousChartType = currentChartType
        currentChartType = chartType
        
        // Only update views if we're in data state
        if case .data = currentState {
            updateViewsForState()
            
            // TECHNICAL INDICATORS: Handle chart type switching
            if chartType == .line && previousChartType == .candlestick {
                // Clear technical indicators when switching FROM candlestick TO line chart
                lineChartView.clearTechnicalIndicators()
                // Clear technical indicators when switching to line chart
            } else if chartType == .candlestick {
                // Reapply technical indicators when switching TO candlestick chart
                reapplyTechnicalIndicators()
                // Reapply technical indicators on candlestick chart
            }
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
                reapplyTechnicalIndicators()
                hasData = true
            }
        }
        
        if let ohlcData = ohlcData {
            self.currentOHLCData = ohlcData
            if !ohlcData.isEmpty {
                let volumeCount = ohlcData.compactMap { $0.volume }.count
                // Process OHLC data
                
                candlestickChartView.update(ohlcData, range: range)
                reapplyTechnicalIndicators()
                applyPendingIndicatorSettings() // Apply any pending settings after data is loaded
                hasData = true
            } else {
                // Only clear and show loading if we're in candlestick mode
                if currentChartType == .candlestick && points == nil {
                    // Clear candlestick chart for empty data
                    candlestickChartView.clear() // Clear the candlestick display
                    currentState = .loading // Show loading when candlestick data is cleared
                    updateViewsForState()
                    return
                }
            }
        }
        
        // Update volume chart ONLY when we have OHLC data (not for line chart points)
        // Volume data comes with OHLC data, so we only update when ohlcData parameter is provided
        if hasData && showVolume && !currentOHLCData.isEmpty && ohlcData != nil {
            updateVolumeData()
        }
        
        // Update state when we have data
        if hasData {
            currentState = .data
            updateViewsForState()
        } else if ohlcData != nil && ohlcData!.isEmpty && currentChartType == .line {
            // If we received empty OHLC data but we're in line mode, don't show loading
            // Ignore empty OHLC data in line chart mode
        }
        
        // Chart updated
    }
    
    // ATOMIC UPDATE: Combines chart data update + settings application to prevent flashing
    func updateChartDataWithSettings(points: [Double]? = nil, ohlcData: [OHLCData]? = nil, range: String, settings: [String: Any]) {
        // Update data first
        updateChartData(points: points, ohlcData: ohlcData, range: range)
        
        // Only apply settings if we have actual chart data to avoid unnecessary redraws
        guard currentState == .data else { return }
        
        // Apply all settings atomically
        applySettingsAtomically(settings)
    }
    
    // Applies settings without triggering multiple redraws
    func applySettingsAtomically(_ settings: [String: Any]) {
        let gridEnabled = settings["gridEnabled"] as? Bool ?? false
        let labelsEnabled = settings["labelsEnabled"] as? Bool ?? false
        let autoScaleEnabled = settings["autoScaleEnabled"] as? Bool ?? false
        let colorTheme = settings["colorTheme"] as? String ?? "classic"
        let lineThickness = settings["lineThickness"] as? Double ?? 0
        let animationSpeed = settings["animationSpeed"] as? Double ?? 0
        let showVolume = settings["showVolume"] as? Bool ?? false

        
        // Apply all settings in one go using existing methods
        toggleGridLines(gridEnabled)
        togglePriceLabels(labelsEnabled)
        toggleAutoScale(autoScaleEnabled)
        
        if let theme = ChartColorTheme(rawValue: colorTheme) {
            applyColorTheme(theme)
        }
        
        if lineThickness > 0 {
            updateLineThickness(lineThickness)
        }
        
        setAnimationSpeed(animationSpeed)
        
        // Apply volume settings to ensure persistence across filter changes
        updateVolumeSettings(showVolume: showVolume)
    }
    
    // New method to handle loading state
    func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            currentState = .loading
            updateViewsForState()
        }
        // Data state is set when data is actually received
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
        volumeChartView.applyColorTheme(theme)
    }
    
    func setAnimationSpeed(_ speed: Double) {
        lineChartView.setAnimationSpeed(speed)
        candlestickChartView.setAnimationSpeed(speed)
    }
    
    // MARK: - Volume Settings
    
    func updateVolumeSettings(showVolume: Bool) {
        self.showVolume = showVolume
        
        // Show/hide volume chart based on settings
        volumeChartView.isHidden = !showVolume
        
        // Force layout update
        chartsStackView.setNeedsLayout()
        chartsStackView.layoutIfNeeded()
        self.setNeedsLayout()
        self.layoutIfNeeded()
        
        // Update volume chart settings if volume is enabled
        if showVolume {
            let indicatorSettings = TechnicalIndicators.loadIndicatorSettings()
            volumeChartView.updateSettings()
            
            // Apply current color theme to volume chart
            let themeRawValue = UserDefaults.standard.string(forKey: "ChartColorTheme") ?? "classic"
            if let theme = ChartColorTheme(rawValue: themeRawValue) {
                volumeChartView.applyColorTheme(theme)
            }
            
            // Volume data updates with OHLC data
            // No need to call updateVolumeData() here to prevent duplicate calls
        }
    }
    
    private func updateVolumeData() {
        // Update volume data
        
        guard showVolume else { 
            // Volume disabled, skip update
            return 
        }
        guard !currentOHLCData.isEmpty else { 
            // No OHLC data available for volume chart
            return 
        }
        
        let themeRawValue = UserDefaults.standard.string(forKey: "ChartColorTheme") ?? "classic"
        let theme = ChartColorTheme(rawValue: themeRawValue) ?? .classic
        
        // Update volume chart
        // Volume chart layout updated
        
        // Update volume chart immediately - no more debouncing
        volumeChartView.updateVolume(ohlcData: currentOHLCData, range: currentRange, theme: theme)
        
        // Synchronize X-axis with main chart immediately - no async delays
        let currentMainChart = currentChartType == .line ? lineChartView : candlestickChartView
        volumeChartView.synchronizeXAxisWith(chartView: currentMainChart)
        
        // Force the volume chart to be visible and update its layout
        volumeChartView.isHidden = false
        volumeChartView.alpha = 1.0
        chartsStackView.setNeedsLayout()
        chartsStackView.layoutIfNeeded()
        
        // Volume chart update complete
    }
    

    
    func applyTechnicalIndicators(_ settings: TechnicalIndicators.IndicatorSettings, theme: ChartColorTheme) {
        // TECHNICAL INDICATORS: Only apply to candlestick charts
        // Line charts don't have OHLC data needed for proper technical analysis
        switch currentChartType {
        case .line:
            // DO NOT apply technical indicators to line charts
            // Clear any existing indicators from line chart
            lineChartView.clearTechnicalIndicators()
            // Technical indicators only supported on candlestick charts
            return
        case .candlestick:
            // ONLY CANDLESTICK: Apply technical indicators where they belong
            // Apply technical indicators to candlestick chart
    
    
    
            
            // ENSURE DATA AVAILABILITY: Only apply if we have data
            if currentOHLCData.isEmpty {
                // Store settings for later application
                // Store the settings for when data becomes available
                storePendingIndicatorSettings(settings, theme: theme)
                return
            }
            
            // Apply indicators - the chart will handle its own refresh
            candlestickChartView.updateWithTechnicalIndicators(settings, theme: theme)
            
            // Technical indicators applied
        }
    }
    
    // MARK: - Pending Indicator Settings
    
    private func storePendingIndicatorSettings(_ settings: TechnicalIndicators.IndicatorSettings, theme: ChartColorTheme) {
        pendingIndicatorSettings = settings
        pendingIndicatorTheme = theme
        // Pending settings stored
    }
    
    private func applyPendingIndicatorSettings() {
        guard let settings = pendingIndicatorSettings,
              let theme = pendingIndicatorTheme,
              currentChartType == .candlestick,
              !currentOHLCData.isEmpty else {
            return
        }
        
                    // Apply pending settings
        candlestickChartView.updateWithTechnicalIndicators(settings, theme: theme)
        
        // Clear pending settings after successful application
        pendingIndicatorSettings = nil
        pendingIndicatorTheme = nil
    }
    
    // MARK: - Technical Indicators Persistence
    
    /// Reapplies any active technical indicator settings after chart data updates
    /// CANDLESTICK ONLY: Technical indicators are only supported on candlestick charts
    private func reapplyTechnicalIndicators() {
        // Technical indicators only work on candlestick charts
        guard currentChartType == .candlestick else {
            // Skip technical indicators for non-candlestick charts
            return
        }
        
        // Load current indicator settings from UserDefaults
        let indicatorSettings = TechnicalIndicators.loadIndicatorSettings()
        
        // Only reapply if any indicators are enabled
        guard indicatorSettings.showSMA || 
              indicatorSettings.showEMA || 
              indicatorSettings.showRSI else {
            return
        }
        
        // Get current color theme
        let themeRawValue = UserDefaults.standard.string(forKey: "ChartColorTheme") ?? "classic"
        let theme = ChartColorTheme(rawValue: themeRawValue) ?? .classic
        
        // Apply indicators to the candlestick chart only
        applyTechnicalIndicators(indicatorSettings, theme: theme)
        
                    // Technical indicators reapplied
    }
}
