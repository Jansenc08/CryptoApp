import UIKit

/**
 * NetworkBannerView
 *
 * A clean, minimalist banner that appears at the top of the screen
 * when there's no internet connection. Styled to match the app's design.
 */
final class NetworkBannerView: UIView {
    
    // MARK: - UI Components
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "No Internet Connection"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
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
        backgroundColor = UIColor.systemRed
        addSubview(messageLabel)
        
        // Accessibility
        isAccessibilityElement = true
        accessibilityLabel = "No internet connection"
        accessibilityTraits = .staticText
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
}