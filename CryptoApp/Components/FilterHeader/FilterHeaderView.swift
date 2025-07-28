//
//  FilterHeaderView.swift
//  CryptoApp
//
//  Created by AI Assistant on 7/7/25.
//

import UIKit

// MARK: - FilterHeaderView Delegate

protocol FilterHeaderViewDelegate: AnyObject {
    func filterHeaderView(_ headerView: FilterHeaderView, didTapPriceChangeButton button: FilterButton)
    func filterHeaderView(_ headerView: FilterHeaderView, didTapTopCoinsButton button: FilterButton)
    func filterHeaderView(_ headerView: FilterHeaderView, didTapAddCoinsButton button: UIButton) // New delegate method
}

// MARK: - FilterHeaderView

class FilterHeaderView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: FilterHeaderViewDelegate?
    
    private var filterState: FilterState = .defaultState {
        didSet {
            updateButtonAppearance()
        }
    }
    
    // Watchlist mode - only shows price change button and + button
    private var isWatchlistMode: Bool = false
    
    private var priceChangeButton: FilterButton!
    private var topCoinsButton: FilterButton!
    private var addCoinsButton: UIButton! // New + button for watchlist mode
    
    // MARK: - Initialization
    
    convenience init(watchlistMode: Bool = false) {
        self.init(frame: .zero)
        self.isWatchlistMode = watchlistMode
        setupUI()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        setupButtons()
        setupStackView()
        setupConstraints()
        updateButtonVisibility()
        updateButtonAppearance()
    }
    
    private func setupButtons() {
        // Price change button (always present)
        let priceDisplayText = filterState.priceChangeDisplayText
        priceChangeButton = FilterButton(title: priceDisplayText.title)
        priceChangeButton.addTarget(self, action: #selector(priceChangeButtonTapped), for: .touchUpInside)
        priceChangeButton.translatesAutoresizingMaskIntoConstraints = false
        
        if isWatchlistMode {
            // Add coins button (only shown in watchlist mode)
            addCoinsButton = UIButton(type: .system)
            addCoinsButton.setImage(UIImage(systemName: "plus"), for: .normal)
            addCoinsButton.tintColor = .systemGray
            addCoinsButton.backgroundColor = .clear
            addCoinsButton.addTarget(self, action: #selector(addCoinsButtonTapped), for: .touchUpInside)
            addCoinsButton.translatesAutoresizingMaskIntoConstraints = false
            
            // Add accessibility
            addCoinsButton.accessibilityLabel = "Add coins to watchlist"
            addCoinsButton.accessibilityHint = "Tap to open the add coins screen"
        } else {
            // Top coins button (only shown in coin list mode)
            let topCoinsDisplayText = filterState.topCoinsDisplayText
            topCoinsButton = FilterButton(title: topCoinsDisplayText.title)
            topCoinsButton.addTarget(self, action: #selector(topCoinsButtonTapped), for: .touchUpInside)
            topCoinsButton.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private func setupStackView() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center  // Center align to prevent height conflicts
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add buttons to stack view based on mode
        if isWatchlistMode {
            // Watchlist: 24h% button on left, + button on right
            stackView.addArrangedSubview(priceChangeButton)
            
            // Add flexible spacer to push + button to the right
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stackView.addArrangedSubview(spacer)
            
            stackView.addArrangedSubview(addCoinsButton)
        } else {
            // Coin list: both buttons on left, compact
            let buttonContainer = UIStackView()
            buttonContainer.axis = .horizontal
            buttonContainer.distribution = .fill
            buttonContainer.alignment = .center  // Center align for consistency
            buttonContainer.spacing = 12
            buttonContainer.addArrangedSubview(priceChangeButton)
            buttonContainer.addArrangedSubview(topCoinsButton)
            
            stackView.addArrangedSubview(buttonContainer)
            
            // Add flexible spacer to keep buttons on the left
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stackView.addArrangedSubview(spacer)
        }
        
        addSubview(stackView)
        
        // Setup constraints for stack view
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    private func setupConstraints() {
        // Set button widths to show full text
        NSLayoutConstraint.activate([
            priceChangeButton.widthAnchor.constraint(equalToConstant: 110)
        ])
        
        if isWatchlistMode {
            NSLayoutConstraint.activate([
                addCoinsButton.widthAnchor.constraint(equalToConstant: 40),
                addCoinsButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        } else {
            NSLayoutConstraint.activate([
                topCoinsButton.widthAnchor.constraint(equalToConstant: 110)
            ])
        }
    }
    
    // MARK: - Public Methods
    
    func updateFilterState(_ newState: FilterState) {
        filterState = newState
    }
    
    func setWatchlistMode(_ watchlistMode: Bool) {
        isWatchlistMode = watchlistMode
        updateButtonVisibility()
    }
    
    func setLoading(_ isLoading: Bool, for buttonType: FilterType) {
        let button: FilterButton?
        
        if buttonType == .priceChange {
            button = priceChangeButton
        } else {
            // Only try to access topCoinsButton if not in watchlist mode
            button = isWatchlistMode ? nil : topCoinsButton
        }
        
        // Simple visual feedback - slight dimming during filter application
        UIView.animate(withDuration: 0.2) {
            button?.alpha = isLoading ? 0.6 : 1.0
            button?.isUserInteractionEnabled = !isLoading
        }
    }
    
    // MARK: - Private Methods
    
    private func updateButtonAppearance() {
        let priceChangeDisplay = filterState.priceChangeDisplayText
        priceChangeButton?.updateTitle(priceChangeDisplay.title)
        
        // Only update top coins button if we're not in watchlist mode
        if !isWatchlistMode {
            let topCoinsDisplay = filterState.topCoinsDisplayText
            topCoinsButton?.updateTitle(topCoinsDisplay.title)
        }
    }
    
    private func updateButtonVisibility() {
        // This method is no longer needed since buttons are only created for their respective modes
        // But keeping it for potential future use or if called from elsewhere
        if isWatchlistMode {
            topCoinsButton?.isHidden = true
            addCoinsButton?.isHidden = false
        } else {
            topCoinsButton?.isHidden = false
            addCoinsButton?.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func priceChangeButtonTapped() {
        delegate?.filterHeaderView(self, didTapPriceChangeButton: priceChangeButton)
    }
    
    @objc private func topCoinsButtonTapped() {
        delegate?.filterHeaderView(self, didTapTopCoinsButton: topCoinsButton)
    }
    
    @objc private func addCoinsButtonTapped() {
        delegate?.filterHeaderView(self, didTapAddCoinsButton: addCoinsButton)
    }
}

// MARK: - Preview Support

#if DEBUG
import SwiftUI

struct FilterHeaderViewPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> FilterHeaderView {
        let headerView = FilterHeaderView()
        return headerView
    }
    
    func updateUIView(_ uiView: FilterHeaderView, context: Context) {
        // No updates needed for preview
    }
}

struct FilterHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        FilterHeaderViewPreview()
            .frame(height: 68)
            .previewLayout(.sizeThatFits)
    }
}
#endif

// MARK: - PopularCoinsHeaderView Delegate

protocol PopularCoinsHeaderViewDelegate: AnyObject {
    func popularCoinsHeaderView(_ headerView: PopularCoinsHeaderView, didSelectFilter filter: PopularCoinsFilter)
}

// MARK: - PopularCoinsHeaderView

class PopularCoinsHeaderView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: PopularCoinsHeaderViewDelegate?
    
    private var popularCoinsState: PopularCoinsState = .defaultState {
        didSet {
            updateButtonAppearance()
        }
    }
    
    private var titleLabel: UILabel!
    private var gainersButton: UIButton!
    private var losersButton: UIButton!
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        setupViews()
        setupConstraints()
        updateButtonAppearance()
    }
    
    private func setupViews() {
        // Title label
        titleLabel = UILabel()
        titleLabel.text = "Popular Coins"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .systemGray
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Create styled buttons without arrows
        gainersButton = createStyledButton(title: PopularCoinsFilter.topGainers.shortDisplayName)
        gainersButton.addTarget(self, action: #selector(gainersButtonTapped), for: .touchUpInside)
        addSubview(gainersButton)
        
        losersButton = createStyledButton(title: PopularCoinsFilter.topLosers.shortDisplayName)
        losersButton.addTarget(self, action: #selector(losersButtonTapped), for: .touchUpInside)
        addSubview(losersButton)
    }
    
    private func createStyledButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.setTitleColor(.white, for: .selected)
        
        // FilterButton-style appearance without arrow
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 8.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor.systemGray4.cgColor
        
        // Shadow for depth
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4.0
        button.layer.shadowOpacity = 0.1
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add touch animations
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: .touchUpOutside)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: .touchCancel)
        
        return button
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.8
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Button stack - positioned to work with FilterButton's 36pt height
            gainersButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            gainersButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gainersButton.widthAnchor.constraint(equalToConstant: 140),
            
            losersButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            losersButton.leadingAnchor.constraint(equalTo: gainersButton.trailingAnchor, constant: 12),
            losersButton.widthAnchor.constraint(equalToConstant: 140)
        ])
    }
    
    // MARK: - Public Methods
    
    func updatePopularCoinsState(_ newState: PopularCoinsState) {
        popularCoinsState = newState
    }
    
    func setLoading(_ isLoading: Bool) {
        // Disable button interactions during loading
        gainersButton.isUserInteractionEnabled = !isLoading
        losersButton.isUserInteractionEnabled = !isLoading
        
        // Reduce opacity during loading for visual feedback
        UIView.animate(withDuration: 0.2) {
            self.gainersButton.alpha = isLoading ? 0.6 : 1.0
            self.losersButton.alpha = isLoading ? 0.6 : 1.0
        }
    }
    
    // MARK: - Private Methods
    
    private func updateButtonAppearance() {
        // Update button states based on current filter
        let isGainersSelected = popularCoinsState.selectedFilter == .topGainers
        let isLosersSelected = popularCoinsState.selectedFilter == .topLosers
        
        // Update gainers button
        gainersButton.isSelected = isGainersSelected
        gainersButton.backgroundColor = isGainersSelected ? .systemBlue : .systemBackground
        gainersButton.layer.borderColor = isGainersSelected ? UIColor.systemBlue.cgColor : UIColor.systemGray4.cgColor
        
        // Update losers button  
        losersButton.isSelected = isLosersSelected
        losersButton.backgroundColor = isLosersSelected ? .systemBlue : .systemBackground
        losersButton.layer.borderColor = isLosersSelected ? UIColor.systemBlue.cgColor : UIColor.systemGray4.cgColor
    }
    
    // MARK: - Actions
    
    @objc private func gainersButtonTapped() {
        delegate?.popularCoinsHeaderView(self, didSelectFilter: .topGainers)
    }
    
    @objc private func losersButtonTapped() {
        delegate?.popularCoinsHeaderView(self, didSelectFilter: .topLosers)
    }
}
