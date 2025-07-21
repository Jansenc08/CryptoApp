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
    
    // Watchlist mode - only shows price change button
    private var isWatchlistMode: Bool = false
    
    // MARK: - UI Components
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var priceChangeButton: FilterButton = {
        let displayText = filterState.priceChangeDisplayText
        let button = FilterButton(title: displayText.title)
        button.addTarget(self, action: #selector(priceChangeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var topCoinsButton: FilterButton = {
        let displayText = filterState.topCoinsDisplayText
        let button = FilterButton(title: displayText.title)
        button.addTarget(self, action: #selector(topCoinsButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    convenience init(watchlistMode: Bool = false) {
        self.init(frame: .zero)
        self.isWatchlistMode = watchlistMode
        updateButtonVisibility()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = UIColor.systemBackground
        setupStackView()
        setupConstraints()
        updateButtonAppearance()
        updateButtonVisibility()
    }
    
    private func setupStackView() {
        addSubview(stackView)
        stackView.addArrangedSubview(priceChangeButton)
        stackView.addArrangedSubview(topCoinsButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Stack view constraints - positioned to the left, no trailing constraint
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            // Button width constraints to make them smaller
            priceChangeButton.widthAnchor.constraint(equalToConstant: 110),
            topCoinsButton.widthAnchor.constraint(equalToConstant: 110),
            
            // Height constraint for the header view
            heightAnchor.constraint(equalToConstant: 68) // 36 (button) + 32 (padding)
        ])
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
        let button = buttonType == .priceChange ? priceChangeButton : topCoinsButton
        
        // Simple visual feedback - slight dimming during filter application
        UIView.animate(withDuration: 0.2) {
            button.alpha = isLoading ? 0.6 : 1.0
            button.isUserInteractionEnabled = !isLoading
        }
    }
    
    // MARK: - Private Methods
    
    private func updateButtonAppearance() {
        let priceChangeDisplay = filterState.priceChangeDisplayText
        let topCoinsDisplay = filterState.topCoinsDisplayText
        
        priceChangeButton.updateTitle(priceChangeDisplay.title)
        topCoinsButton.updateTitle(topCoinsDisplay.title)
    }
    
    private func updateButtonVisibility() {
        topCoinsButton.isHidden = isWatchlistMode
        
        // Remove/add top coins button from stack view based on mode
        if isWatchlistMode {
            if stackView.arrangedSubviews.contains(topCoinsButton) {
                stackView.removeArrangedSubview(topCoinsButton)
            }
        } else {
            if !stackView.arrangedSubviews.contains(topCoinsButton) {
                stackView.addArrangedSubview(topCoinsButton)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func priceChangeButtonTapped() {
        delegate?.filterHeaderView(self, didTapPriceChangeButton: priceChangeButton)
    }
    
    @objc private func topCoinsButtonTapped() {
        delegate?.filterHeaderView(self, didTapTopCoinsButton: topCoinsButton)
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
