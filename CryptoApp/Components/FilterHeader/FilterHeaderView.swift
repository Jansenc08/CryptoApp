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
