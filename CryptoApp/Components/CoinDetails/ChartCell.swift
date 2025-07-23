import UIKit

final class ChartCell: UITableViewCell {
    private let lineChartView = ChartView()
    private let candlestickChartView = CandlestickChartView()
    private let containerView = UIView()
    
    // Loading and error state views
    private let loadingView = UIView()
    private let loadingLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorView = UIView()
    private let errorLabel = UILabel()
    
    private var currentChartType: ChartType = .line
    private var currentPoints: [Double] = []
    private var currentOHLCData: [OHLCData] = []
    private var currentRange: String = "24h"
    
    // Chart state tracking
    private enum ChartState {
        case loading
        case data
        case error(String)
    }
    
    private var currentState: ChartState = .data

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    private func setupUI() {
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
        containerView.addSubview(lineChartView)
        containerView.addSubview(candlestickChartView)
        
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
    }
    
    private func setupLoadingView() {
        // Loading container
        containerView.addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.backgroundColor = .systemBackground
        loadingView.isHidden = true
        
        // Activity indicator
        loadingView.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .systemBlue
        
        // Loading label
        loadingView.addSubview(loadingLabel)
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Loading chart data..."
        loadingLabel.textAlignment = .center
        loadingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textColor = .secondaryLabel
        
        // Layout loading view
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            loadingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),
            
            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: loadingView.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingView.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupErrorView() {
        // Error container
        containerView.addSubview(errorView)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = .systemBackground
        errorView.isHidden = true
        
        // Error label
        errorView.addSubview(errorLabel)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "No chart data available"
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 16, weight: .medium)
        errorLabel.textColor = .secondaryLabel
        errorLabel.numberOfLines = 0
        
        // Layout error view
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: containerView.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            errorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            errorLabel.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: errorView.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: errorView.trailingAnchor, constant: -20)
        ])
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
            // Show loading, hide charts and error
            loadingView.isHidden = false
            errorView.isHidden = true
            lineChartView.isHidden = true
            candlestickChartView.isHidden = true
            activityIndicator.startAnimating()
            print("📊 Chart cell showing loading state")
            
        case .data:
            // Show appropriate chart based on type, hide loading and error
            loadingView.isHidden = true
            errorView.isHidden = true
            activityIndicator.stopAnimating()
            
            let showLineChart = (currentChartType == .line)
            lineChartView.isHidden = !showLineChart
            candlestickChartView.isHidden = showLineChart
            print("📊 Chart cell showing data state for \(currentChartType.rawValue) chart")
            
        case .error(let message):
            // Show error, hide charts and loading
            loadingView.isHidden = true
            errorView.isHidden = false
            lineChartView.isHidden = true
            candlestickChartView.isHidden = true
            activityIndicator.stopAnimating()
            errorLabel.text = message
            print("📊 Chart cell showing error state: \(message)")
        }
    }

    // Configure with line chart data
    func configure(points: [Double], range: String) {
        self.currentPoints = points
        self.currentRange = range
        
        if !points.isEmpty {
            currentState = .data
            lineChartView.update(points, range: range)
            updateViewsForState()
        }
    }
    
    // Configure with OHLC data for candlestick chart
    func configure(ohlcData: [OHLCData], range: String) {
        self.currentOHLCData = ohlcData
        self.currentRange = range
        
        if !ohlcData.isEmpty {
            currentState = .data
            candlestickChartView.update(ohlcData, range: range)
            updateViewsForState()
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
                    print("📊 Received empty OHLC data - clearing candlestick chart for \(range)")
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
            print("📊 Ignoring empty OHLC data - in line chart mode")
        }
        
        print("📊 Updated chart cell with range: \(range), chart type: \(currentChartType)")
    }
    
    // New method to handle loading state
    func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            currentState = .loading
            updateViewsForState()
        }
        // Note: We don't set .data state here since that should only happen when we actually receive data
    }
    

    
    // New method to handle error state
    func showErrorState(_ message: String) {
        currentState = .error(message)
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
