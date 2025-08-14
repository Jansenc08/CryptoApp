import UIKit

/**
 * NetworkBannerView
 *
 * A clean, minimalist banner that appears at the top of the screen
 * when there's no internet connection. Styled to match the app's design.
 */
final class NetworkBannerView: UIView {
    
    // MARK: - UI Components
    
    private let redDotIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "No Internet Connection"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label // Adapts to light/dark mode
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel // Adapts to light/dark mode
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupConstraints()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = UIColor.systemGray6 // Adapts to light/dark mode automatically
        addSubview(redDotIndicator)
        addSubview(messageLabel)
        addSubview(timestampLabel)
        
        // Set initial timestamp
        updateTimestamp()
        
        // Accessibility
        isAccessibilityElement = true
        accessibilityLabel = "No internet connection"
        accessibilityTraits = .staticText
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Red dot indicator
            redDotIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            redDotIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            redDotIndicator.widthAnchor.constraint(equalToConstant: 8),
            redDotIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            // Message label
            messageLabel.leadingAnchor.constraint(equalTo: redDotIndicator.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: timestampLabel.leadingAnchor, constant: -8),
            
            // Timestamp label
            timestampLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            timestampLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            timestampLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            // Banner height
            self.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Public Methods
    
    private func updateTimestamp() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: Date())
        timestampLabel.text = "Last updated \(timeString)"
    }
}