import UIKit

final class ChartCell: UITableViewCell {
    private let chartView = ChartView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add Chart to cell content
        contentView.addSubview(chartView)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: contentView.topAnchor),
            chartView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            chartView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    // Configure chart with new data
    func configure(points: [Double], range: String) {
        chartView.update(with: points, range: range)
    }
    
    // Allows setting a scroll callback
    // Chartview detects user scrolling
    // Chartview tells Chartcell
    // Chartcell tells VC
    // VC tells ViewModel and VM fetches data 
    var onScrollToEdge: ((ChartView.ScrollDirection) -> Void)? {
        get { chartView.onScrollToEdge }
        set { chartView.onScrollToEdge = newValue }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
