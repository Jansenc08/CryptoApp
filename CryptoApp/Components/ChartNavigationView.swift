//
//  ChartNavigationView.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

class ChartNavigationView: UIView {
    
    private let scrollLeftButton = UIButton(type: .system)
    private let scrollRightButton = UIButton(type: .system)
    private let latestButton = UIButton(type: .system)
    private let oldestButton = UIButton(type: .system)
    
    var onScrollLeft: (() -> Void)?
    var onScrollRight: (() -> Void)?
    var onScrollToLatest: (() -> Void)?
    var onScrollToOldest: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        
        // Configure buttons
        configureButton(scrollLeftButton, title: "←", action: #selector(scrollLeftTapped))
        configureButton(scrollRightButton, title: "→", action: #selector(scrollRightTapped))
        configureButton(latestButton, title: "Latest", action: #selector(latestTapped))
        configureButton(oldestButton, title: "Oldest", action: #selector(oldestTapped))
        
        // Layout
        let navigationStack = UIStackView(arrangedSubviews: [scrollLeftButton, scrollRightButton])
        navigationStack.axis = .horizontal
        navigationStack.spacing = 20
        navigationStack.distribution = .fillEqually
        
        let quickActionStack = UIStackView(arrangedSubviews: [oldestButton, latestButton])
        quickActionStack.axis = .horizontal
        quickActionStack.spacing = 20
        quickActionStack.distribution = .fillEqually
        
        let mainStack = UIStackView(arrangedSubviews: [navigationStack, quickActionStack])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    private func configureButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Add press animation
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }
    
    @objc private func scrollLeftTapped() {
        onScrollLeft?()
    }
    
    @objc private func scrollRightTapped() {
        onScrollRight?()
    }
    
    @objc private func latestTapped() {
        onScrollToLatest?()
    }
    
    @objc private func oldestTapped() {
        onScrollToOldest?()
    }
}
