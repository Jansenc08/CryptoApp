import UIKit

final class SmoothingHelpVC: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Close button
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        closeButton.tintColor = UIColor.systemGray
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // Title
        titleLabel.text = "📊 Smoothing Algorithms"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = UIColor.label
        titleLabel.textAlignment = .center
        
        // Subtitle
        subtitleLabel.text = "Choose the right algorithm for your analysis style"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        // Setup scroll view
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubviews(closeButton, titleLabel, subtitleLabel)
        
        // Create algorithm cards
        createAlgorithmCards()
    }
    
    private func createAlgorithmCards() {
        let algorithms = [
            AlgorithmInfo(
                icon: "⚡",
                name: "Adaptive",
                badge: "RECOMMENDED",
                description: "Smart choice that automatically selects between Simple Moving Average (SMA) and Exponential Moving Average (EMA) based on your timeframe",
                benefits: ["Perfect for beginners", "Works on all timeframes", "No configuration needed"],
                color: UIColor.systemBlue
            ),
            AlgorithmInfo(
                icon: "📈",
                name: "Basic",
                badge: "SIMPLE",
                description: "Simple Moving Average (SMA) smoothing that creates clean, predictable results with equal weight for all data points",
                benefits: ["Easy to understand", "Consistent results", "Low processing overhead"],
                color: UIColor.systemGreen
            ),
            AlgorithmInfo(
                icon: "🚀",
                name: "Crypto-Optimized",
                badge: "ADVANCED",
                description: "Savitzky-Golay filter that preserves important price spikes while smoothing out noise using polynomial regression",
                benefits: ["Keeps flash crashes visible", "Perfect for volatile markets", "Maintains key price events"],
                color: UIColor.systemOrange
            ),
            AlgorithmInfo(
                icon: "🧹",
                name: "Clean Data",
                badge: "UTILITY",
                description: "Median filter that removes API errors, flash crashes, and data anomalies by replacing outliers with median values",
                benefits: ["Filters out bad data", "Removes outliers", "Clean visualization"],
                color: UIColor.systemPurple
            ),
            AlgorithmInfo(
                icon: "✨",
                name: "Smooth",
                badge: "PRESENTATION",
                description: "LOESS (Local Regression) algorithm that creates ultra-smooth flowing curves using weighted local regression",
                benefits: ["Professional appearance", "Elegant curves", "Great for reports"],
                color: UIColor.systemTeal
            )
        ]
        
        var previousCard: UIView?
        
        for algorithm in algorithms {
            let card = createAlgorithmCard(for: algorithm)
            contentView.addSubview(card)
            
            NSLayoutConstraint.activate([
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            ])
            
            if let previous = previousCard {
                card.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 16).isActive = true
            } else {
                card.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32).isActive = true
            }
            
            if algorithm.name == "Smooth" {
                // Last card - add bottom constraint
                card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32).isActive = true
            }
            
            previousCard = card
        }
    }
    
    private func createAlgorithmCard(for algorithm: AlgorithmInfo) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let iconLabel = UILabel()
        iconLabel.text = algorithm.icon
        iconLabel.font = UIFont.systemFont(ofSize: 32)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Badge - Create a container view for better padding control
        let badgeContainer = UIView()
        badgeContainer.backgroundColor = algorithm.color
        badgeContainer.layer.cornerRadius = 12
        badgeContainer.layer.masksToBounds = true
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let badgeLabel = UILabel()
        badgeLabel.text = algorithm.badge
        badgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor = UIColor.white
        badgeLabel.textAlignment = .center
        badgeLabel.numberOfLines = 1
        badgeLabel.adjustsFontSizeToFitWidth = true
        badgeLabel.minimumScaleFactor = 0.8
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        badgeContainer.addSubview(badgeLabel)
        
        // Name
        let nameLabel = UILabel()
        nameLabel.text = algorithm.name
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = UIColor.label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Description
        let descriptionLabel = UILabel()
        descriptionLabel.text = algorithm.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = UIColor.secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Benefits stack
        let benefitsStack = UIStackView()
        benefitsStack.axis = .vertical
        benefitsStack.spacing = 4
        benefitsStack.translatesAutoresizingMaskIntoConstraints = false
        
        for benefit in algorithm.benefits {
            let benefitLabel = UILabel()
            benefitLabel.text = "• \(benefit)"
            benefitLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            benefitLabel.textColor = UIColor.secondaryLabel
            benefitLabel.numberOfLines = 0
            benefitsStack.addArrangedSubview(benefitLabel)
        }
        
        // Add all subviews
        card.addSubviews(iconLabel, badgeContainer, nameLabel, descriptionLabel, benefitsStack)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Icon
            iconLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            
            // Badge Container
            badgeContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            badgeContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            badgeContainer.heightAnchor.constraint(equalToConstant: 24),
            
            // Badge Label inside container
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -8),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4),
            
            // Name - positioned to the right of the icon
            nameLabel.centerYAnchor.constraint(equalTo: iconLabel.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -8),
            
            // Description - positioned below the icon/name row
            descriptionLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            // Benefits
            benefitsStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            benefitsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            benefitsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            benefitsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 50),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Data Model

private struct AlgorithmInfo {
    let icon: String
    let name: String
    let badge: String
    let description: String
    let benefits: [String]
    let color: UIColor
}
