//
//  InfoCell.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

final class InfoCell: UITableViewCell {
    let nameLabel = UILabel() // Made internal for animation access
    let rankLabel = UILabel() // Made internal for animation access
    let priceLabel = UILabel() // Made internal for animation access
    let priceChangeLabel = UILabel() // Price change indicator
    private let priceChangeContainer = UIView() // Container for the price change label with background
    private let rankContainer = UIView() // Container for the rank label with grey background
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Configure labels
        nameLabel.font = .boldSystemFont(ofSize: 24)
        rankLabel.font = .systemFont(ofSize: 14, weight: .medium)
        rankLabel.textColor = .secondaryLabel
        rankLabel.textAlignment = .center
        priceLabel.font = .systemFont(ofSize: 20)
        
        // Configure rank container with grey background
        rankContainer.backgroundColor = .tertiarySystemFill
        rankContainer.layer.cornerRadius = 8
        rankContainer.translatesAutoresizingMaskIntoConstraints = false
        rankContainer.addSubview(rankLabel)
        
        // Set up rank label constraints inside container
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rankLabel.topAnchor.constraint(equalTo: rankContainer.topAnchor, constant: 4),
            rankLabel.bottomAnchor.constraint(equalTo: rankContainer.bottomAnchor, constant: -4),
            rankLabel.leadingAnchor.constraint(equalTo: rankContainer.leadingAnchor, constant: 8),
            rankLabel.trailingAnchor.constraint(equalTo: rankContainer.trailingAnchor, constant: -8)
        ])
        
        // Configure price change label
        priceChangeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        priceChangeLabel.textColor = .white
        priceChangeLabel.textAlignment = .center
        priceChangeLabel.text = "" // Initially empty
        
        // Configure price change container - MODERN APPROACH
        priceChangeContainer.layer.cornerRadius = 8
        priceChangeContainer.isHidden = true
        priceChangeContainer.translatesAutoresizingMaskIntoConstraints = false
        priceChangeContainer.addSubview(priceChangeLabel)
        
        // MODERN CONSTRAINT-BASED LAYOUT
        priceChangeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            priceChangeLabel.topAnchor.constraint(equalTo: priceChangeContainer.topAnchor, constant: 4),
            priceChangeLabel.bottomAnchor.constraint(equalTo: priceChangeContainer.bottomAnchor, constant: -4),
            priceChangeLabel.leadingAnchor.constraint(equalTo: priceChangeContainer.leadingAnchor, constant: 8),
            priceChangeLabel.trailingAnchor.constraint(equalTo: priceChangeContainer.trailingAnchor, constant: -8)
        ])
        
        // CRITICAL: Set explicit width constraints for badge behavior
        priceChangeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        priceChangeContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 100).isActive = true
        
        rankContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        rankContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 60).isActive = true
        
        // MODERN PRIORITY SETUP - Badges should stay compact
        priceChangeContainer.setContentHuggingPriority(.required, for: .horizontal)
        priceChangeContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        rankContainer.setContentHuggingPriority(.required, for: .horizontal)
        rankContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // Name priorities - Optimized for longer names
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal) // Allow compression for long names
        
        // Price label priorities
        priceLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // MODERN STACKVIEW LAYOUT
        // Create spacer for top row to keep name and rank together
        let topSpacer = UIView()
        topSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // Top row: name + rank container + spacer (keeps "Bitcoin #1" together)
        let topRow = UIStackView(arrangedSubviews: [nameLabel, rankContainer, topSpacer])
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .firstBaseline
        topRow.distribution = .fill
        
        // Create spacer for price row to push badge to the right
        let priceSpacer = UIView()
        priceSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // Bottom row: price + spacer + badge (ensures badge stays compact)
        let priceRow = UIStackView(arrangedSubviews: [priceLabel, priceSpacer, priceChangeContainer])
        priceRow.axis = .horizontal
        priceRow.spacing = 12
        priceRow.alignment = .center
        priceRow.distribution = .fill

        // Main vertical stack
        stack.axis = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(priceRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(name: String, rank: Int, price: String) {
        nameLabel.text = name
        rankLabel.text = "#\(rank)"
        priceLabel.text = price
    }
    
    /// Configure with price change indicator
    func configure(name: String, rank: Int, price: String, priceChange: Double?, percentageChange: Double?) {
        nameLabel.text = name
        rankLabel.text = "#\(rank)"
        priceLabel.text = price
        
        if let change = priceChange, let percentage = percentageChange {
            showPermanentPriceChangeIndicator(priceChange: change, percentageChange: percentage)
        } else {
            hidePriceChangeIndicator()
        }
    }
    
    /// Show permanent price change indicator (24h change)
    func showPermanentPriceChangeIndicator(priceChange: Double, percentageChange: Double) {
        let isPositive = percentageChange >= 0
        let changeText = "\(isPositive ? "+" : "")\(String(format: "%.2f", percentageChange))%"
        
        priceChangeLabel.text = changeText
        priceChangeContainer.backgroundColor = isPositive ? .systemGreen : .systemRed
        priceChangeContainer.isHidden = false
        priceChangeContainer.alpha = 1 // Always visible
    }
    
    /// Update the price change indicator with new values (for real-time changes)
    func updatePriceChangeIndicator(priceChange: Double, percentageChange: Double) {
        let isPositive = priceChange >= 0
        let changeText = "\(isPositive ? "+" : "")$\(String(format: "%.2f", abs(priceChange)))"
        
        // Update to show the real-time change amount temporarily
        priceChangeLabel.text = changeText
        priceChangeContainer.backgroundColor = isPositive ? .systemGreen : .systemRed
        priceChangeContainer.isHidden = false
        
        print("🎨 InfoCell: Real-time change - \(changeText) (isPositive: \(isPositive))")
        
        // Animate the appearance for real-time changes
        animateChangeIndicator()
        
        // After 5 seconds, revert back to showing the 24h percentage change
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.revertToPermanentDisplay()
        }
    }
    
    /// Revert back to showing the permanent 24h percentage change
    private func revertToPermanentDisplay() {
        // This will be called to restore the 24h percentage display
        // The actual data will be updated when the next coin data update occurs
        print("💡 Reverting price change indicator to 24h display")
    }
    
    /// Hide the price change indicator
    func hidePriceChangeIndicator() {
        priceChangeContainer.isHidden = true
    }
    
    /// Flash the price label when price changes
    func flashPrice(isPositive: Bool) {
        PriceFlashHelper.shared.flashPriceLabel(priceLabel, isPositive: isPositive)
    }
    
    /// Animate the price change indicator (for real-time updates, temporary effect)
    private func animateChangeIndicator() {
        // Scale animation to draw attention
        priceChangeContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.priceChangeContainer.transform = .identity
        }
        
        // Gentle pulsing effect for the first 2 seconds to highlight the change
        UIView.animate(withDuration: 0.8, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction]) {
            self.priceChangeContainer.alpha = 0.8
        }
        
        // Stop the pulsing after 3 seconds and keep the new color visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.priceChangeContainer.layer.removeAllAnimations()
            self?.priceChangeContainer.alpha = 1
            print("💡 Price change indicator settled - keeping new color visible")
        }
    }
}
