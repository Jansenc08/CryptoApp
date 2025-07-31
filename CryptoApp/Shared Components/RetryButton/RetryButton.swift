import UIKit

/// A reusable retry button component with proper iOS styling and animations
/// Follows iOS Human Interface Guidelines for error recovery
final class RetryButton: UIButton {
    
    // MARK: - Properties
    
    private let iconImageView = UIImageView()
    private let customTitleLabel = UILabel()
    private let stackView = UIStackView()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var retryAction: (() -> Void)?
    private var isCompact: Bool = false
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure button appearance
        backgroundColor = .systemGray
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        
        // Add padding for better touch area
        contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        // Configure icon
        iconImageView.image = UIImage(systemName: "arrow.clockwise")
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure title
        customTitleLabel.text = "Retry"
        customTitleLabel.textColor = .white
        customTitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        customTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure stack view
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add views to hierarchy
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(customTitleLabel)
        addSubview(stackView)
        
        // Setup constraints (will be updated in configure methods)
        setupConstraints()
        
        // Setup accessibility
        accessibilityLabel = "Retry loading data"
        accessibilityHint = "Double tap to retry loading the failed data"
        accessibilityTraits = .button
        
        // Setup visual effects
        setupVisualEffects()
    }
    
    private func setupVisualEffects() {
        // Add subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        
        // Prepare haptic generator
        impactGenerator.prepare()
    }
    
    private func setupActions() {
        addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    // MARK: - Setup Methods
    
    private func setupConstraints() {
        let iconSize: CGFloat = isCompact ? 14 : 16
        let buttonHeight: CGFloat = isCompact ? 40 : 44  // Increased minimum for better touch
        let minWidth: CGFloat = isCompact ? 100 : 100    // Ensure adequate width
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            iconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconSize),
            
            heightAnchor.constraint(greaterThanOrEqualToConstant: buttonHeight),
            widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth)
        ])
        
        // Update font size for compact mode
        if isCompact {
            customTitleLabel.font = .systemFont(ofSize: 15, weight: .medium)  // Slightly larger
            stackView.spacing = 8
        }
    }
    
    // Ensure minimum touch area (iOS HIG recommends 44x44 minimum)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let minimumTouchArea: CGFloat = 44.0
        let touchArea = CGRect(
            x: bounds.midX - minimumTouchArea / 2,
            y: bounds.midY - minimumTouchArea / 2,
            width: minimumTouchArea,
            height: minimumTouchArea
        )
        
        if touchArea.contains(point) {
            return self
        }
        
        return super.hitTest(point, with: event)
    }
    
    // MARK: - Actions
    
    @objc private func retryButtonTapped() {
        print("🔄 RetryButton: Button tapped successfully")
        animateRetry()
        impactGenerator.impactOccurred()
        retryAction?()
    }
    
    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)  // Less aggressive scaling
            self.backgroundColor = UIColor.systemGray.withAlphaComponent(0.7)
        }
    }
    
    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = .identity
            self.backgroundColor = .systemGray
        }
    }
    
    // MARK: - Animations
    
    private func animateRetry() {
        // Rotate the retry icon
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 0.5
        rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        iconImageView.layer.add(rotation, forKey: "rotation")
    }
    
    // MARK: - Public Interface
    
    /// Sets the retry action to be called when button is tapped
    /// - Parameter action: The closure to execute on retry
    func setRetryAction(_ action: @escaping () -> Void) {
        self.retryAction = action
    }
    
    /// Configures the button for compact display (smaller size for charts)
    func enableCompactMode() {
        isCompact = true
        
        // Remove existing constraints
        NSLayoutConstraint.deactivate(constraints)
        
        // Apply new compact constraints
        setupConstraints()
    }
    
    /// Updates the button title
    /// - Parameter title: The new title text
    func setTitle(_ title: String) {
        customTitleLabel.text = title
        accessibilityLabel = "\(title) loading data"
    }
    
    /// Shows loading state with spinner
    func showLoading() {
        isEnabled = false
        customTitleLabel.text = "Retrying..."
        
        // Replace icon with activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        
        // Temporarily replace icon
        iconImageView.isHidden = true
        stackView.insertArrangedSubview(activityIndicator, at: 0)
        
        // Reset after delay (will be called by parent when request completes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Minimum loading time for better UX
        }
    }
    
    /// Hides loading state and restores normal appearance
    func hideLoading() {
        isEnabled = true
        customTitleLabel.text = "Retry"
        
        // Remove activity indicator and restore icon
        if let activityIndicator = stackView.arrangedSubviews.first(where: { $0 is UIActivityIndicatorView }) {
            stackView.removeArrangedSubview(activityIndicator)
            activityIndicator.removeFromSuperview()
        }
        
        iconImageView.isHidden = false
    }
}

// MARK: - Convenience Initializers

extension RetryButton {
    
    /// Creates a retry button with a custom title
    /// - Parameters:
    ///   - title: The button title
    ///   - action: The retry action to execute
    convenience init(title: String = "Retry", action: @escaping () -> Void) {
        self.init(frame: .zero)
        setTitle(title)
        setRetryAction(action)
    }
    
    /// Creates a compact retry button for smaller spaces
    convenience init(compact: Bool, action: @escaping () -> Void) {
        self.init(frame: .zero)
        
        if compact {
            customTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
            stackView.spacing = 6
            
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 36),
                widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
            ])
        }
        
        setRetryAction(action)
    }
} 