//
//  PriceChangeOverviewCell.swift
//  CryptoApp
//
//  Created by AI Assistant on 1/9/25.
//

import UIKit

final class PriceChangeOverviewCell: UITableViewCell {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let timePeriodsStackView = UIStackView()
    
    // MARK: - Time Period Data Structure
    
    private struct TimePeriod {
        let title: String
        let value: Double?
        
        var isPositive: Bool {
            return (value ?? 0) >= 0
        }
        
        var formattedValue: String {
            guard let value = value else { return "N/A" }
            let sign = value >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", value))%"
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Container setup - white in light mode, gray in dark mode
        containerView.backgroundColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? .secondarySystemBackground 
                : .systemBackground
        }
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.05
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Time periods stack view
        timePeriodsStackView.axis = .horizontal
        timePeriodsStackView.distribution = .fillEqually
        timePeriodsStackView.spacing = 8
        timePeriodsStackView.alignment = .fill
        timePeriodsStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(timePeriodsStackView)
        
        // Layout constraints - reduced padding for more compact layout
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8), // Reduced from 12
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8), // Reduced from 12
            
            timePeriodsStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12), // Reduced from 16
            timePeriodsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            timePeriodsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            timePeriodsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12) // Reduced from 16
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with coin: Coin) {
        // Clear existing time period views
        timePeriodsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Get quote data
        guard let usdQuote = coin.quote?["USD"] else {
            AppLogger.ui("PriceChangeOverviewCell: No USD quote data for \(coin.symbol)", level: .warning)
            createEmptyState()
            return
        }
        
        // Define time periods with available data (similar to CoinMarketCap)
        let timePeriods: [TimePeriod] = [
            TimePeriod(title: "24 hours", value: usdQuote.percentChange24h),
            TimePeriod(title: "7 days", value: usdQuote.percentChange7d),
            TimePeriod(title: "30 days", value: usdQuote.percentChange30d),
            TimePeriod(title: "90 days", value: usdQuote.percentChange90d)
        ]
        
        AppLogger.ui("PriceChangeOverviewCell: Configuring for \(coin.symbol)")
        for (index, timePeriod) in timePeriods.enumerated() {
            AppLogger.ui("   \(index): \(timePeriod.title) = \(timePeriod.value?.description ?? "nil") (\(timePeriod.formattedValue))")
        }
        
        // Create views for each time period
        for timePeriod in timePeriods {
            let periodView = createTimePeriodView(for: timePeriod)
            timePeriodsStackView.addArrangedSubview(periodView)
        }
    }
    
    private func createTimePeriodView(for timePeriod: TimePeriod) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Period title label
        let titleLabel = UILabel()
        titleLabel.text = timePeriod.title
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.backgroundColor = .clear
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add triangle indicator for positive/negative changes
        let indicatorLabel = UILabel()
        if let value = timePeriod.value {
            indicatorLabel.text = value >= 0 ? "▲" : "▼"
            indicatorLabel.textColor = value >= 0 ? .systemGreen : .systemRed
        } else {
            indicatorLabel.text = "—"
            indicatorLabel.textColor = .secondaryLabel
        }
        indicatorLabel.font = .systemFont(ofSize: 8)
        indicatorLabel.backgroundColor = .clear
        indicatorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Percentage change label
        let valueLabel = UILabel()
        valueLabel.text = timePeriod.formattedValue
        valueLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        valueLabel.numberOfLines = 1
        valueLabel.backgroundColor = .clear
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Set color based on positive/negative change
        if timePeriod.value != nil {
            valueLabel.textColor = timePeriod.isPositive ? .systemGreen : .systemRed
        } else {
            valueLabel.textColor = .secondaryLabel
        }
        
        // Horizontal stack for indicator + value
        let valueStackView = UIStackView(arrangedSubviews: [indicatorLabel, valueLabel])
        valueStackView.axis = .horizontal
        valueStackView.spacing = 4
        valueStackView.alignment = .center
        valueStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Main vertical stack view
        let stackView = UIStackView(arrangedSubviews: [titleLabel, valueStackView])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        
        return containerView
    }
    
    private func createEmptyState() {
        let emptyLabel = UILabel()
        emptyLabel.text = "Price change data not available"
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .tertiaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        timePeriodsStackView.addArrangedSubview(emptyLabel)
    }
    

} 