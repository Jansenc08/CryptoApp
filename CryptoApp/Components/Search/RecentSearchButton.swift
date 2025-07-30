import UIKit

/**
 * RecentSearchButton
 * 
 * COIN-BASED UI COMPONENT for recent searches
 * - Displays coin logo and symbol in a rounded button style
 * - Navigates directly to coin details when tapped
 * - Clean, modern design with proper spacing
 * - No API calls - just UI
 */
final class RecentSearchButton: UIButton {
    
    // MARK: - Properties
    
    private let recentSearchItem: RecentSearchItem
    private let onTap: (RecentSearchItem) -> Void
    private var coinImageView: CoinImageView!
    private var symbolLabel: UILabel!
    
    // MARK: - Initialization
    
    init(recentSearchItem: RecentSearchItem, onTap: @escaping (RecentSearchItem) -> Void) {
        self.recentSearchItem = recentSearchItem
        self.onTap = onTap
        super.init(frame: .zero)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupButton() {
        // Button styling - smaller corner radius for smaller button
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 15
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
        
        // Create coin image view (use existing CoinImageView for consistency and caching)
        coinImageView = CoinImageView()
        coinImageView.translatesAutoresizingMaskIntoConstraints = false
        coinImageView.layer.cornerRadius = 10
        coinImageView.layer.masksToBounds = true
        addSubview(coinImageView)
        
        // Create label for symbol
        symbolLabel = UILabel()
        symbolLabel.translatesAutoresizingMaskIntoConstraints = false
        symbolLabel.text = recentSearchItem.symbol
        symbolLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        symbolLabel.textColor = .label
        symbolLabel.textAlignment = .center
        addSubview(symbolLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Button size - made smaller
            widthAnchor.constraint(equalToConstant: 65),
            heightAnchor.constraint(equalToConstant: 30),
            
            // Coin image constraints
            coinImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            coinImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            coinImageView.widthAnchor.constraint(equalToConstant: 20),
            coinImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Symbol label constraints
            symbolLabel.leadingAnchor.constraint(equalTo: coinImageView.trailingAnchor, constant: 3),
            symbolLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            symbolLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Load coin logo if available
        if let logoUrl = recentSearchItem.logoUrl {
            coinImageView.downloadImage(fromURL: logoUrl)
        } else {
            coinImageView.setPlaceholder()
        }
        
        // Touch handling
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        // Accessibility
        accessibilityLabel = "Recent search: \(recentSearchItem.name)"
        accessibilityHint = "Double tap to view \(recentSearchItem.name) details"
    }
    
    // MARK: - Image Loading handled by CoinImageView
    
    // MARK: - Actions
    
    @objc private func buttonTapped() {
        AppLogger.search("Recent Search Button: Tapped \(recentSearchItem.symbol) (\(recentSearchItem.name))")
        onTap(recentSearchItem)
    }
    
    deinit {
        // Clean up closure to prevent memory leaks - not strictly necessary for this use case
        // but good practice for closure properties
        AppLogger.ui("RecentSearchButton deinit - cleaned up for \(recentSearchItem.symbol)")
    }
} 