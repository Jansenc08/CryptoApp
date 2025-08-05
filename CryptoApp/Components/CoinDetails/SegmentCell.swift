//
//  SegmentCell.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

import UIKit

final class SegmentCell: UITableViewCell {
    private let container = UIView()
    private let segmentView = SegmentView()
    private let chartTypeToggle = UIButton(type: .system)
    private let landscapeToggle = UIButton(type: .system)
    private let chartSettingsToggle = UIButton(type: .system)
    
    // Chart type callback
    var onChartTypeToggle: ((ChartType) -> Void)?
    // Landscape toggle callback
    var onLandscapeToggle: (() -> Void)?
    // Chart settings callback
    var onChartSettingsToggle: (() -> Void)?
    private var currentChartType: ChartType = .line

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    private func setupUI() {
        contentView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 52) // Ensure minimum height for buttons
        ])

        // Setup toggle buttons
        setupChartTypeToggle()
        setupLandscapeToggle()
        setupChartSettingsToggle()
        
        // Add all views to container
        container.addSubviews(segmentView, landscapeToggle, chartTypeToggle, chartSettingsToggle)
        
        segmentView.translatesAutoresizingMaskIntoConstraints = false
        landscapeToggle.translatesAutoresizingMaskIntoConstraints = false
        chartTypeToggle.translatesAutoresizingMaskIntoConstraints = false
        chartSettingsToggle.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Segment view - independent height, centered vertically
            segmentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            segmentView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            segmentView.heightAnchor.constraint(equalToConstant: 36), // Smaller height for segment control
            segmentView.trailingAnchor.constraint(equalTo: landscapeToggle.leadingAnchor, constant: -12),
            
            // Landscape toggle button - maintains 40x40 size
            landscapeToggle.trailingAnchor.constraint(equalTo: chartTypeToggle.leadingAnchor, constant: -8),
            landscapeToggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            landscapeToggle.widthAnchor.constraint(equalToConstant: 40),
            landscapeToggle.heightAnchor.constraint(equalToConstant: 40),
            
            // Chart type toggle button - maintains 40x40 size
            chartTypeToggle.trailingAnchor.constraint(equalTo: chartSettingsToggle.leadingAnchor, constant: -8),
            chartTypeToggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chartTypeToggle.widthAnchor.constraint(equalToConstant: 40),
            chartTypeToggle.heightAnchor.constraint(equalToConstant: 40),
            
            // Chart settings toggle button - maintains 40x40 size
            chartSettingsToggle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chartSettingsToggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chartSettingsToggle.widthAnchor.constraint(equalToConstant: 40),
            chartSettingsToggle.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupChartTypeToggle() {
        // Clean, minimalist icon button design
        chartTypeToggle.backgroundColor = .systemGray6
        chartTypeToggle.layer.cornerRadius = 12  // Perfect for 40x40 button
        chartTypeToggle.layer.borderWidth = 0
        
        // Clean appearance without shadows
        chartTypeToggle.layer.masksToBounds = true
        
        updateChartTypeToggleAppearance()
        
        // Simple touch interaction
        chartTypeToggle.addTarget(self, action: #selector(chartTypeToggleTapped), for: .touchUpInside)
    }
    
    private func updateChartTypeToggleAppearance() {
        // Use just an icon for cleaner look
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: currentChartType.systemImageName, withConfiguration: config)
        
        // Simple color scheme
        let (tintColor, backgroundColor): (UIColor, UIColor)
        
        switch currentChartType {
        case .line:
            tintColor = UIColor.systemBlue
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        case .candlestick:
            tintColor = UIColor.systemOrange
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        }
        
        // Clean icon-only design
        chartTypeToggle.setImage(image, for: .normal)
        chartTypeToggle.setTitle("", for: .normal) // Remove text to avoid wrapping
        chartTypeToggle.backgroundColor = backgroundColor
        chartTypeToggle.tintColor = tintColor
        chartTypeToggle.imageView?.contentMode = .scaleAspectFit
        
        // Simple transition
        UIView.animate(withDuration: 0.2) {
            self.chartTypeToggle.alpha = 0.8
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.chartTypeToggle.alpha = 1.0
            }
        }
    }
    
    private func setupLandscapeToggle() {
        // Clean, minimalist landscape button design
        landscapeToggle.backgroundColor = .systemGray6
        landscapeToggle.layer.cornerRadius = 12
        landscapeToggle.layer.masksToBounds = true
        
        // Landscape icon
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "rotate.right", withConfiguration: config)
        
        landscapeToggle.setImage(image, for: .normal)
        landscapeToggle.tintColor = .systemBlue
        landscapeToggle.imageView?.contentMode = .scaleAspectFit
        
        // Add action
        landscapeToggle.addTarget(self, action: #selector(landscapeToggleTapped), for: .touchUpInside)
    }
    
    private func setupChartSettingsToggle() {
        // Clean, minimalist settings button design
        chartSettingsToggle.backgroundColor = .systemGray6
        chartSettingsToggle.layer.cornerRadius = 12
        chartSettingsToggle.layer.masksToBounds = true
        
        // Settings gear icon
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "gearshape", withConfiguration: config)
        
        chartSettingsToggle.setImage(image, for: .normal)
        chartSettingsToggle.tintColor = .systemBlue
        chartSettingsToggle.imageView?.contentMode = .scaleAspectFit
        
        // Add action
        chartSettingsToggle.addTarget(self, action: #selector(chartSettingsToggleTapped), for: .touchUpInside)
    }
    
    @objc private func landscapeToggleTapped() {
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Brief animation
        UIView.animate(withDuration: 0.1) {
            self.landscapeToggle.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.landscapeToggle.transform = .identity
            }
        }
        
        // Notify callback
        onLandscapeToggle?()
    }
    
    @objc private func chartTypeToggleTapped() {
        // Toggle chart type
        currentChartType = currentChartType == .line ? .candlestick : .line
        updateChartTypeToggleAppearance()
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Notify callback
        onChartTypeToggle?(currentChartType)
    }
    
    @objc private func chartSettingsToggleTapped() {
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Brief animation
        UIView.animate(withDuration: 0.1) {
            self.chartSettingsToggle.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.chartSettingsToggle.transform = .identity
            }
        }
        
        // Notify callback
        onChartSettingsToggle?()
    }

    func configure(items: [String], chartType: ChartType = .line, onTimeRangeSelect: @escaping (String) -> Void) {
        segmentView.configure(withItems: items)
        segmentView.onSelectionChanged = { index in
            onTimeRangeSelect(items[index])
        }
        
        // Update chart type if different
        if currentChartType != chartType {
            currentChartType = chartType
            updateChartTypeToggleAppearance()
        }
    }
    
    func setLandscapeToggleCallback(_ callback: @escaping () -> Void) {
        onLandscapeToggle = callback
    }
    
    func setChartSettingsCallback(_ callback: @escaping () -> Void) {
        onChartSettingsToggle = callback
    }
    
    func setChartType(_ chartType: ChartType) {
        if currentChartType != chartType {
            currentChartType = chartType
            updateChartTypeToggleAppearance()
        }
        }
    
    func setSelectedRange(_ range: String) {
        let ranges = ["24h", "7d", "30d", "All"]
        if let index = ranges.firstIndex(of: range) {
            segmentView.setSelectedIndex(index)
        }
    }
    
    func setSelectedRangeSilently(_ range: String) {
        let ranges = ["24h", "7d", "30d", "All"]
        if let index = ranges.firstIndex(of: range) {
            segmentView.setSelectedIndexSilently(index)
        }
    }
  
    required init?(coder: NSCoder) { fatalError() }
    
    deinit {
        // Clean up closure properties to prevent memory leaks
        onChartTypeToggle = nil
        onLandscapeToggle = nil
        onChartSettingsToggle = nil
        AppLogger.ui("SegmentCell deinit - cleaned up closures")
    }
}
