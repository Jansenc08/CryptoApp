import UIKit

final class ChartCell: UITableViewCell {
    private let lineChartView = ChartView()
    private let candlestickChartView = CandlestickChartView()
    private let containerView = UIView()
    
    private var currentChartType: ChartType = .line
    private var currentPoints: [Double] = []
    private var currentOHLCData: [OHLCData] = []
    private var currentRange: String = "24h"

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
        
        // Initially show line chart
        showChart(type: .line, animated: false)
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

    // Configure with line chart data
    func configure(points: [Double], range: String) {
        self.currentPoints = points
        self.currentRange = range
        lineChartView.update(points, range: range)
    }
    
    // Configure with OHLC data for candlestick chart
    func configure(ohlcData: [OHLCData], range: String) {
        self.currentOHLCData = ohlcData
        self.currentRange = range
        candlestickChartView.update(ohlcData, range: range)
    }
    
    // Switch chart type
    func switchChartType(to chartType: ChartType) {
        guard chartType != currentChartType else { return }
        showChart(type: chartType, animated: true)
    }
    
    // Update chart data without recreation
    func updateChartData(points: [Double]? = nil, ohlcData: [OHLCData]? = nil, range: String) {
        self.currentRange = range
        
        if let points = points {
            self.currentPoints = points
            lineChartView.update(points, range: range)
        }
        
        if let ohlcData = ohlcData {
            self.currentOHLCData = ohlcData
            candlestickChartView.update(ohlcData, range: range)
        }
        
        print("📊 Updated chart cell with range: \(range), chart type: \(currentChartType)")
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
    
    func updateLoadingState(_ isLoading: Bool) {
        // Show/hide loading indicator for both charts
        lineChartView.alpha = isLoading ? 0.5 : 1.0
        candlestickChartView.alpha = isLoading ? 0.5 : 1.0
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
        }
    }
}
