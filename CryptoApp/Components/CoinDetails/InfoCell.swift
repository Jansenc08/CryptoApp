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
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        nameLabel.font = .boldSystemFont(ofSize: 24)
        rankLabel.font = .systemFont(ofSize: 16)
        rankLabel.textColor = .secondaryLabel
        priceLabel.font = .systemFont(ofSize: 20)
        
        // Configure price change label
        priceChangeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        priceChangeLabel.textColor = .white
        priceChangeLabel.textAlignment = .center
        priceChangeLabel.text = "" // Initially empty
        
        // Configure price change container
        priceChangeContainer.layer.cornerRadius = 8
        priceChangeContainer.isHidden = true // Initially hidden
        priceChangeContainer.translatesAutoresizingMaskIntoConstraints = false
        priceChangeContainer.addSubview(priceChangeLabel)
        
        priceChangeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            priceChangeLabel.topAnchor.constraint(equalTo: priceChangeContainer.topAnchor, constant: 4),
            priceChangeLabel.bottomAnchor.constraint(equalTo: priceChangeContainer.bottomAnchor, constant: -4),
            priceChangeLabel.leadingAnchor.constraint(equalTo: priceChangeContainer.leadingAnchor, constant: 8),
            priceChangeLabel.trailingAnchor.constraint(equalTo: priceChangeContainer.trailingAnchor, constant: -8)
        ])

        // Set Name label to be beside rank label 
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Horizontal Stack: name + rank
        let topRow = UIStackView(arrangedSubviews: [nameLabel, rankLabel])
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .firstBaseline
        topRow.distribution = .fill
        
        // Horizontal Stack: price + price change indicator
        let priceRow = UIStackView(arrangedSubviews: [priceLabel, priceChangeContainer])
        priceRow.axis = .horizontal
        priceRow.spacing = 12
        priceRow.alignment = .center
        priceRow.distribution = .fill

        // Main Vertical Stack
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
        
        priceChangeLabel.text = changeText
        priceChangeContainer.backgroundColor = isPositive ? .systemGreen : .systemRed
        priceChangeContainer.isHidden = false
        
        // Animate the appearance for real-time changes
        animateChangeIndicator()
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
        // Scale animation
        priceChangeContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.priceChangeContainer.transform = .identity
        }
        
        // Flash effect for real-time changes (but don't hide)
        UIView.animate(withDuration: 0.2, delay: 0, options: [.autoreverse, .repeat]) {
            self.priceChangeContainer.alpha = 0.7
        } completion: { _ in
            self.priceChangeContainer.alpha = 1
        }
        
        // Stop the flash after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.priceChangeContainer.layer.removeAllAnimations()
            self?.priceChangeContainer.alpha = 1
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
