import UIKit

/**
 * OfflineErrorView
 *
 * A full-screen error view shown when the user tries to access content while offline.
 * Features a clean design with floating geometric shapes and retry functionality.
 */
final class OfflineErrorView: UIView {
    
    // MARK: - Properties
    
    var onRetryTapped: (() -> Void)?
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let illustrationContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Something went wrong"
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "You may refresh this page to try again or come back later."
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try again", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // Floating shapes for illustration
    private var floatingShapes: [UIView] = []
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
        setupActions()
        createFloatingShapes()
        startFloatingAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupConstraints()
        setupActions()
        createFloatingShapes()
        startFloatingAnimation()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .systemBackground
        
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(illustrationContainer)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(retryButton)
        
        retryButton.addSubview(loadingIndicator)
        
        // Accessibility
        titleLabel.accessibilityTraits = .header
        retryButton.accessibilityLabel = "Try again button"
        retryButton.accessibilityHint = "Attempts to reconnect to the internet and reload the page"
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Illustration container (centered in upper portion)
            illustrationContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
            illustrationContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            illustrationContainer.widthAnchor.constraint(equalToConstant: 200),
            illustrationContainer.heightAnchor.constraint(equalToConstant: 200),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: illustrationContainer.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            // Retry button
            retryButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            retryButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            retryButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            retryButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: retryButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: retryButton.centerYAnchor),
            
            // Content view height constraint
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.heightAnchor)
        ])
    }
    
    private func setupActions() {
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }
    
    // MARK: - Floating Shapes Animation
    
    private func createFloatingShapes() {
        // Create the main blue cylinder/box in center
        let mainShape = createShape(type: .cylinder, size: CGSize(width: 60, height: 60), color: .systemBlue)
        illustrationContainer.addSubview(mainShape)
        
        // Create floating triangles
        let triangle1 = createShape(type: .triangle, size: CGSize(width: 30, height: 30), color: .systemGray3)
        let triangle2 = createShape(type: .triangle, size: CGSize(width: 25, height: 25), color: .systemGray4)
        let triangle3 = createShape(type: .triangle, size: CGSize(width: 20, height: 20), color: .systemGray5)
        
        illustrationContainer.addSubview(triangle1)
        illustrationContainer.addSubview(triangle2)
        illustrationContainer.addSubview(triangle3)
        
        floatingShapes = [mainShape, triangle1, triangle2, triangle3]
        
        // Position shapes
        positionShapes()
    }
    
    private func createShape(type: ShapeType, size: CGSize, color: UIColor) -> UIView {
        let shape = UIView(frame: CGRect(origin: .zero, size: size))
        shape.backgroundColor = color
        shape.translatesAutoresizingMaskIntoConstraints = false
        
        switch type {
        case .cylinder:
            shape.layer.cornerRadius = 8
            // Add perspective shadow
            shape.layer.shadowColor = UIColor.black.cgColor
            shape.layer.shadowOffset = CGSize(width: 0, height: 4)
            shape.layer.shadowRadius = 8
            shape.layer.shadowOpacity = 0.1
        case .triangle:
            shape.layer.cornerRadius = 4
            shape.transform = CGAffineTransform(rotationAngle: .pi / 4)
        }
        
        return shape
    }
    
    private func positionShapes() {
        guard floatingShapes.count >= 4 else { return }
        
        let mainShape = floatingShapes[0]
        let triangle1 = floatingShapes[1]
        let triangle2 = floatingShapes[2]
        let triangle3 = floatingShapes[3]
        
        NSLayoutConstraint.activate([
            // Main shape (center)
            mainShape.centerXAnchor.constraint(equalTo: illustrationContainer.centerXAnchor),
            mainShape.centerYAnchor.constraint(equalTo: illustrationContainer.centerYAnchor),
            mainShape.widthAnchor.constraint(equalToConstant: 60),
            mainShape.heightAnchor.constraint(equalToConstant: 60),
            
            // Triangle 1 (top left)
            triangle1.centerXAnchor.constraint(equalTo: illustrationContainer.leadingAnchor, constant: 40),
            triangle1.centerYAnchor.constraint(equalTo: illustrationContainer.topAnchor, constant: 50),
            triangle1.widthAnchor.constraint(equalToConstant: 30),
            triangle1.heightAnchor.constraint(equalToConstant: 30),
            
            // Triangle 2 (top right)
            triangle2.centerXAnchor.constraint(equalTo: illustrationContainer.trailingAnchor, constant: -30),
            triangle2.centerYAnchor.constraint(equalTo: illustrationContainer.topAnchor, constant: 70),
            triangle2.widthAnchor.constraint(equalToConstant: 25),
            triangle2.heightAnchor.constraint(equalToConstant: 25),
            
            // Triangle 3 (bottom left)
            triangle3.centerXAnchor.constraint(equalTo: illustrationContainer.leadingAnchor, constant: 50),
            triangle3.centerYAnchor.constraint(equalTo: illustrationContainer.bottomAnchor, constant: -40),
            triangle3.widthAnchor.constraint(equalToConstant: 20),
            triangle3.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    private func startFloatingAnimation() {
        for (index, shape) in floatingShapes.enumerated() {
            let delay = Double(index) * 0.2
            let duration = 3.0 + Double(index) * 0.5
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.animateShape(shape, duration: duration)
            }
        }
    }
    
    private func animateShape(_ shape: UIView, duration: Double) {
        UIView.animate(withDuration: duration, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            let randomX = CGFloat.random(in: -10...10)
            let randomY = CGFloat.random(in: -15...15)
            let randomRotation = CGFloat.random(in: -0.2...0.2)
            
            shape.transform = shape.transform.concatenating(CGAffineTransform(translationX: randomX, y: randomY))
            shape.transform = shape.transform.concatenating(CGAffineTransform(rotationAngle: randomRotation))
        }
    }
    
    // MARK: - Actions
    
    @objc private func retryTapped() {
        setRetryButtonLoading(true)
        
        // Add haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        onRetryTapped?()
    }
    
    // MARK: - Public Methods
    
    func setRetryButtonLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            if loading {
                self.retryButton.setTitle("", for: .normal)
                self.loadingIndicator.startAnimating()
                self.retryButton.isEnabled = false
                self.retryButton.alpha = 0.8
            } else {
                self.retryButton.setTitle("Try again", for: .normal)
                self.loadingIndicator.stopAnimating()
                self.retryButton.isEnabled = true
                self.retryButton.alpha = 1.0
            }
        }
    }
    
    func updateForConnectionStatus(_ isConnected: Bool) {
        if isConnected {
            setRetryButtonLoading(false)
        }
    }
}

// MARK: - Supporting Types

private enum ShapeType {
    case cylinder
    case triangle
}
