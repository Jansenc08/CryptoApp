//
//  SearchVC.swift
//  CryptoApp
//
//  Created by AI Assistant on 1/7/25.
//

import UIKit
import Combine

@objc final class SearchVC: UIViewController {
    
    // MARK: - Section Enum for Diffable Data Source
    
    enum SearchSection {
        case main
    }
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private var searchController: UISearchController!
    private let viewModel = SearchVM()
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<SearchSection, Coin>!
    
    // MARK: - Recent Searches Properties
    
    private var recentSearchesContainer: UIView!
    private var recentSearchesScrollView: UIScrollView!
    private var recentSearchesStackView: UIStackView!
    private var recentSearchesLabel: UILabel!
    private var clearRecentSearchesButton: UIButton!
    private let recentSearchManager = RecentSearchManager.shared
    
    // MARK: - Dynamic Constraints
    
    private var collectionViewTopWithRecentSearches: NSLayoutConstraint!
    private var collectionViewTopWithoutRecentSearches: NSLayoutConstraint!
    
    // MARK: - Navigation Properties
    
    private var shouldPresentKeyboardOnLoad = false
    private var hasAppeared = false
    private var emptyStateView: UIView?
    
    // MARK: - Search State
    
    private var currentSearchResults: [Coin] = [] // Track current search results for saving recent searches
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureSearchController()
        configureRecentSearches()
        configureCollectionView()
        configureDataSource()
        bindViewModel()
        setupEmptyState()
        loadRecentSearches()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure proper navigation bar state
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        
        // Refresh recent searches when returning to search
        loadRecentSearches()
        
        // Setup but don't present keyboard yet - wait for viewDidAppear
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Present keyboard if coming from search icon (not tab bar) and this is first appearance
        if shouldPresentKeyboardOnLoad && !hasAppeared {
            hasAppeared = true
            // Use longer delay for simulator compatibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.searchController.searchBar.becomeFirstResponder()
            }
            shouldPresentKeyboardOnLoad = false
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Dismiss keyboard when leaving
        searchController.searchBar.resignFirstResponder()
        
        // Reset navigation bar state when leaving search
        if isMovingFromParent || isBeingDismissed {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - UI Setup
    
    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Search"
        
        // Configure large title display mode only for this view
        navigationItem.largeTitleDisplayMode = .always
    }
    
    private func configureSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search cryptocurrencies..."
        
        // Customize search bar appearance
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.tintColor = .systemGreen
        
        // Configure search suggestions
        searchController.searchBar.scopeButtonTitles = nil
        searchController.automaticallyShowsCancelButton = true
        
        // Add search controller to navigation item
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Ensure search bar is always visible
        definesPresentationContext = true
    }
    
    private func configureRecentSearches() {
        // Container for recent searches
        recentSearchesContainer = UIView()
        recentSearchesContainer.translatesAutoresizingMaskIntoConstraints = false
        recentSearchesContainer.backgroundColor = .systemBackground
        recentSearchesContainer.isHidden = true // Hidden by default - no space when empty
        view.addSubview(recentSearchesContainer)
        
        // Title label
        recentSearchesLabel = UILabel()
        recentSearchesLabel.translatesAutoresizingMaskIntoConstraints = false
        recentSearchesLabel.text = "Recent Searches"
        recentSearchesLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        recentSearchesLabel.textColor = .systemGray
        recentSearchesContainer.addSubview(recentSearchesLabel)
        
        // Clear button
        clearRecentSearchesButton = UIButton(type: .system)
        clearRecentSearchesButton.translatesAutoresizingMaskIntoConstraints = false
        clearRecentSearchesButton.setTitle("Clear", for: .normal)
        clearRecentSearchesButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        clearRecentSearchesButton.setTitleColor(.systemRed, for: .normal)
        clearRecentSearchesButton.addTarget(self, action: #selector(clearRecentSearchesButtonTapped), for: .touchUpInside)
        recentSearchesContainer.addSubview(clearRecentSearchesButton)
        
        // Horizontal scroll view for buttons
        recentSearchesScrollView = UIScrollView()
        recentSearchesScrollView.translatesAutoresizingMaskIntoConstraints = false
        recentSearchesScrollView.showsHorizontalScrollIndicator = false
        recentSearchesScrollView.showsVerticalScrollIndicator = false
        recentSearchesContainer.addSubview(recentSearchesScrollView)
        
        // Stack view to hold buttons
        recentSearchesStackView = UIStackView()
        recentSearchesStackView.translatesAutoresizingMaskIntoConstraints = false
        recentSearchesStackView.axis = .horizontal
        recentSearchesStackView.spacing = 12
        recentSearchesStackView.alignment = .center
        recentSearchesScrollView.addSubview(recentSearchesStackView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Container constraints
            recentSearchesContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            recentSearchesContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recentSearchesContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recentSearchesContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Label constraints
            recentSearchesLabel.topAnchor.constraint(equalTo: recentSearchesContainer.topAnchor, constant: 12),
            recentSearchesLabel.leadingAnchor.constraint(equalTo: recentSearchesContainer.leadingAnchor, constant: 16),
            
            // Clear button constraints
            clearRecentSearchesButton.topAnchor.constraint(equalTo: recentSearchesContainer.topAnchor, constant: 12),
            clearRecentSearchesButton.trailingAnchor.constraint(equalTo: recentSearchesContainer.trailingAnchor, constant: -16),
            clearRecentSearchesButton.leadingAnchor.constraint(greaterThanOrEqualTo: recentSearchesLabel.trailingAnchor, constant: 8),
            
            // Scroll view constraints
            recentSearchesScrollView.topAnchor.constraint(equalTo: recentSearchesLabel.bottomAnchor, constant: 8),
            recentSearchesScrollView.leadingAnchor.constraint(equalTo: recentSearchesContainer.leadingAnchor, constant: 16),
            recentSearchesScrollView.trailingAnchor.constraint(equalTo: recentSearchesContainer.trailingAnchor, constant: -16),
            recentSearchesScrollView.bottomAnchor.constraint(equalTo: recentSearchesContainer.bottomAnchor, constant: -12),
            
            // Stack view constraints
            recentSearchesStackView.topAnchor.constraint(equalTo: recentSearchesScrollView.topAnchor),
            recentSearchesStackView.leadingAnchor.constraint(equalTo: recentSearchesScrollView.leadingAnchor),
            recentSearchesStackView.trailingAnchor.constraint(equalTo: recentSearchesScrollView.trailingAnchor),
            recentSearchesStackView.bottomAnchor.constraint(equalTo: recentSearchesScrollView.bottomAnchor),
            recentSearchesStackView.heightAnchor.constraint(equalTo: recentSearchesScrollView.heightAnchor)
        ])
    }
    
    private func configureCollectionView() {
        // Create layout
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.bounds.width, height: 80)
        layout.minimumLineSpacing = 0
        
        // Initialize collection view
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.keyboardDismissMode = .onDrag
        
        // Register cell
        collectionView.register(CoinCell.self, forCellWithReuseIdentifier: CoinCell.reuseID())
        
        view.addSubview(collectionView)
        
        // Create two different top constraints
        collectionViewTopWithRecentSearches = collectionView.topAnchor.constraint(equalTo: recentSearchesContainer.bottomAnchor)
        collectionViewTopWithoutRecentSearches = collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        
        // Activate common constraints
        NSLayoutConstraint.activate([
            collectionViewTopWithoutRecentSearches, // Start with no space (recent searches hidden)
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SearchSection, Coin>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CoinCell.reuseID(),
                for: indexPath
            ) as? CoinCell else {
                return UICollectionViewCell()
            }
            
            let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }
            
            // Configure the cell
            cell.configure(
                withRank: coin.cmcRank,
                name: coin.symbol,
                price: coin.priceString,
                market: coin.marketSupplyString,
                percentChange24h: coin.percentChange24hString,
                sparklineData: sparklineNumbers,
                isPositiveChange: coin.isPositiveChange
            )
            
            // Load coin logo if available
            if let urlString = self?.viewModel.currentCoinLogos[coin.id] {
                cell.coinImageView.downloadImage(fromURL: urlString)
            } else {
                cell.coinImageView.setPlaceholder()
            }
            
            return cell
        }
        
        collectionView.dataSource = dataSource
    }
    
    // MARK: - ViewModel Binding
    
    private func bindViewModel() {
        // Bind search results
        viewModel.searchResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                // Track current search results for saving recent searches
                self?.currentSearchResults = results
                
                self?.updateDataSource(results)
                // Get current search text from the search controller instead of ViewModel
                let currentSearchText = self?.searchController.searchBar.text ?? ""
                self?.updateEmptyState(isEmpty: results.isEmpty, searchText: currentSearchText)
            }
            .store(in: &cancellables)
        
        // Bind loading state
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    LoadingView.show(in: self?.collectionView)
                } else {
                    LoadingView.dismiss(from: self?.collectionView)
                }
            }
            .store(in: &cancellables)
        
        // Bind error messages
        viewModel.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(title: "Search Error", message: error)
            }
            .store(in: &cancellables)
        
        // Bind logo updates
        viewModel.coinLogos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Reload visible cells to update logos
                DispatchQueue.main.async {
                    self?.collectionView.reloadData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Source Updates
    
    private func updateDataSource(_ coins: [Coin]) {
        var snapshot = NSDiffableDataSourceSnapshot<SearchSection, Coin>()
        snapshot.appendSections([.main])
        snapshot.appendItems(coins)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    // MARK: - Empty State
    
    private func setupEmptyState() {
        emptyStateView = createEmptyStateView(
            title: "Search Cryptocurrencies",
            message: "Enter a coin name or symbol to search",
            imageName: "magnifyingglass.circle"
        )
        emptyStateView?.isHidden = true
        view.addSubview(emptyStateView!)
        
        NSLayoutConstraint.activate([
            emptyStateView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView!.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyStateView!.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func createEmptyStateView(title: String, message: String, imageName: String) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Image view
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: imageName)
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Message label
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        messageLabel.textColor = .tertiaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    private func updateEmptyState(isEmpty: Bool, searchText: String) {
        guard let emptyStateView = emptyStateView else { return }
        
        if isEmpty && !searchText.isEmpty {
            // Show "no results" state
            updateEmptyStateContent(
                title: "No Results Found",
                message: "No cryptocurrencies match '\(searchText)'\nTry a different search term",
                imageName: "exclamationmark.magnifyingglass"
            )
            emptyStateView.isHidden = false
            
            // Hide recent searches when showing no results
            showRecentSearches(false)
        } else if isEmpty && searchText.isEmpty {
            // Show initial state or recent searches
            let hasRecentSearches = !recentSearchManager.getRecentSearchItems().isEmpty
            
            if hasRecentSearches {
                // Hide empty state and show recent searches
                emptyStateView.isHidden = true
                showRecentSearches(true)
            } else {
                // Show empty state and hide recent searches
                updateEmptyStateContent(
                    title: "Search Cryptocurrencies",
                    message: "Enter a coin name or symbol to search",
                    imageName: "magnifyingglass.circle"
                )
                emptyStateView.isHidden = false
                showRecentSearches(false)
            }
        } else {
            // Hide empty state when there are results
            emptyStateView.isHidden = true
        }
    }
    
    private func updateEmptyStateContent(title: String, message: String, imageName: String) {
        guard let emptyStateView = emptyStateView else { return }
        
        if let imageView = emptyStateView.subviews.first(where: { $0 is UIImageView }) as? UIImageView {
            imageView.image = UIImage(systemName: imageName)
        }
        
        if let titleLabel = emptyStateView.subviews.first(where: { 
            $0 is UILabel && ($0 as! UILabel).font.pointSize == 20 
        }) as? UILabel {
            titleLabel.text = title
        }
        
        if let messageLabel = emptyStateView.subviews.first(where: { 
            $0 is UILabel && ($0 as! UILabel).font.pointSize == 16 
        }) as? UILabel {
            messageLabel.text = message
        }
    }
    
    // MARK: - Alert Helper
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Public Methods
    
    /**
     * CONFIGURE KEYBOARD PRESENTATION
     * 
     * Call this method to control whether the keyboard should automatically appear
     * when the search view loads. Used to differentiate between tab bar access
     * and search icon access.
     */
    @objc func setShouldPresentKeyboard(_ shouldPresent: Bool) {
        shouldPresentKeyboardOnLoad = shouldPresent
    }
    
    /**
     * Clear all recent searches
     */
    @objc private func clearRecentSearchesButtonTapped() {
        let alert = UIAlertController(
            title: "Clear Recent Searches",
            message: "Are you sure you want to clear all recent searches?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.recentSearchManager.clearRecentSearches()
            self?.loadRecentSearches() // Refresh the UI
            
            // Update empty state since there are no recent searches now
            self?.updateEmptyState(isEmpty: self?.currentSearchResults.isEmpty ?? true, 
                                  searchText: self?.searchController.searchBar.text ?? "")
            
            print("🗑️ User cleared all recent searches")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - UISearchResultsUpdating

extension SearchVC: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        
        // Update the view model's search text which triggers the debounced search
        viewModel.updateSearchText(searchText)
        
        // Show/hide recent searches based on search text
        if searchText.isEmpty {
            showRecentSearches(!recentSearchManager.getRecentSearchItems().isEmpty)
        } else {
            showRecentSearches(false)
        }
    }
}

// MARK: - UISearchBarDelegate

extension SearchVC: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        // Save search term if it has results
        let searchText = searchBar.text ?? ""
        if !searchText.isEmpty && !currentSearchResults.isEmpty {
            saveRecentSearch(searchText)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        viewModel.clearSearch()
        
        // Show recent searches when canceling
        showRecentSearches(!recentSearchManager.getRecentSearchItems().isEmpty)
    }
}

// MARK: - UICollectionViewDelegate

extension SearchVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        // Dismiss keyboard
        searchController.searchBar.resignFirstResponder()
        
        // Navigate to coin details
        let selectedCoin = currentSearchResults[indexPath.item]
        
        // Save this as a recent search since user selected it
        let logoUrl = viewModel.currentCoinLogos[selectedCoin.id]
        recentSearchManager.addRecentSearch(
            coinId: selectedCoin.id,
            symbol: selectedCoin.symbol,
            name: selectedCoin.name,
            logoUrl: logoUrl,
            slug: selectedCoin.slug
        )
        
        let detailsVC = CoinDetailsVC(coin: selectedCoin)
        navigationController?.pushViewController(detailsVC, animated: true)
    }
}

// MARK: - Recent Searches

extension SearchVC {
    
    /**
     * Load and display recent searches
     */
    private func loadRecentSearches() {
        let recentSearchItems = recentSearchManager.getRecentSearchItems()
        print("🔍 Recent Searches: Found \(recentSearchItems.count) searches: \(recentSearchItems.map { $0.symbol })")
        displayRecentSearches(recentSearchItems)
        showRecentSearches(!recentSearchItems.isEmpty)
    }
    
    /**
     * Display recent search buttons
     */
    private func displayRecentSearches(_ searchItems: [RecentSearchItem]) {
        // Clear existing buttons
        recentSearchesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add new buttons
        for searchItem in searchItems {
            let button = RecentSearchButton(recentSearchItem: searchItem) { [weak self] item in
                self?.recentSearchButtonTapped(item)
            }
            recentSearchesStackView.addArrangedSubview(button)
        }
        
        print("🔍 Recent Searches: Displayed \(searchItems.count) buttons")
    }
    
    /**
     * Show or hide recent searches container
     */
    private func showRecentSearches(_ show: Bool) {
        // Update container visibility
        recentSearchesContainer.isHidden = !show
        
        // Switch constraints to remove/add space
        if show {
            collectionViewTopWithoutRecentSearches.isActive = false
            collectionViewTopWithRecentSearches.isActive = true
        } else {
            collectionViewTopWithRecentSearches.isActive = false
            collectionViewTopWithoutRecentSearches.isActive = true
        }
        
        // Animate the layout change
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
        
        print("🔍 Recent Searches: \(show ? "Showing" : "Hiding") container")
    }
    
    /**
     * Handle recent search button tap - find real coin data and navigate
     */
    private func recentSearchButtonTapped(_ searchItem: RecentSearchItem) {
        print("🔍 Recent Search: Tapped \(searchItem.symbol) - finding real coin data")
        
        // First try to find the coin in current search results
        if let cachedCoin = findCoinInCache(coinId: searchItem.coinId) {
            print("🔍 Found cached coin data for \(searchItem.symbol)")
            let detailsVC = CoinDetailsVC(coin: cachedCoin)
            navigationController?.pushViewController(detailsVC, animated: true)
            return
        }
        
        // If not found, search for the coin by symbol to get real data
        print("🔍 Searching for \(searchItem.symbol) to get real coin data")
        searchForCoinAndNavigate(searchItem: searchItem)
    }
    
    /**
     * Search for a specific coin and navigate to its details when found
     */
    private func searchForCoinAndNavigate(searchItem: RecentSearchItem) {
        // Store the original search text to restore later
        let originalSearchText = searchController.searchBar.text ?? ""
        
        // Trigger search for this specific coin
        searchController.searchBar.text = searchItem.symbol
        viewModel.updateSearchText(searchItem.symbol)
        
        // Wait for search results and then navigate
        viewModel.searchResults
            .receive(on: DispatchQueue.main)
            .first { !$0.isEmpty } // Wait for non-empty results
            .timeout(.seconds(3), scheduler: DispatchQueue.main) // 3 second timeout
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                                            print("⚠️ Search timeout for \(searchItem.symbol) - using fallback navigation")
                    self?.navigate(searchItem: searchItem, fallbackText: originalSearchText)
                    }
                },
                receiveValue: { [weak self] searchResults in
                    guard let self = self else { return }
                    
                    // Find the matching coin in search results
                    if let matchingCoin = searchResults.first(where: { 
                        $0.id == searchItem.coinId || $0.symbol.lowercased() == searchItem.symbol.lowercased() 
                    }) {
                        print("✅ Found real coin data for \(searchItem.symbol)")
                        
                        // Restore original search text
                        self.searchController.searchBar.text = originalSearchText
                        self.viewModel.updateSearchText(originalSearchText)
                        
                        // Navigate with real coin data
                        let detailsVC = CoinDetailsVC(coin: matchingCoin)
                        self.navigationController?.pushViewController(detailsVC, animated: true)
                    } else {
                                            print("⚠️ Coin not found in search results - using fallback")
                    self.navigate(searchItem: searchItem, fallbackText: originalSearchText)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /**
     * Fallback navigation when real coin data cannot be found
     */
    private func navigate(searchItem: RecentSearchItem, fallbackText originalSearchText: String) {
        // Restore original search text
        searchController.searchBar.text = originalSearchText
        viewModel.updateSearchText(originalSearchText)
        
        // Show alert that coin details may be limited
        let alert = UIAlertController(
            title: "Limited Data",
            message: "Some details for \(searchItem.symbol) may not be available. The coin page will show basic information only.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            let fallbackCoin = self?.createFallbackCoin(from: searchItem)
            if let coin = fallbackCoin {
                let detailsVC = CoinDetailsVC(coin: coin)
                self?.navigationController?.pushViewController(detailsVC, animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    /**
     * Save search result as recent search with coin information
     */
    private func saveRecentSearch(_ searchTerm: String) {
        let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 2 else { return }
        
        // Find the best matching coin from search results
        if let matchingCoin = findBestMatchingCoin(for: trimmed) {
            let logoUrl = viewModel.currentCoinLogos[matchingCoin.id]
            recentSearchManager.addRecentSearch(
                coinId: matchingCoin.id,
                symbol: matchingCoin.symbol,
                name: matchingCoin.name,
                logoUrl: logoUrl,
                slug: matchingCoin.slug
            )
            loadRecentSearches()
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Find coin in cached search data
     */
    private func findCoinInCache(coinId: Int) -> Coin? {
        // Check current search results first
        return currentSearchResults.first(where: { $0.id == coinId })
    }
    
    /**
     * Find best matching coin from current search results
     */
    private func findBestMatchingCoin(for searchTerm: String) -> Coin? {
        let lowercaseSearch = searchTerm.lowercased()
        
        // First try exact symbol match
        if let exactMatch = currentSearchResults.first(where: { $0.symbol.lowercased() == lowercaseSearch }) {
            return exactMatch
        }
        
        // Then try exact name match
        if let exactMatch = currentSearchResults.first(where: { $0.name.lowercased() == lowercaseSearch }) {
            return exactMatch
        }
        
        // Finally return first result if any
        return currentSearchResults.first
    }
    
    /**
     * Create fallback coin object when cached data is not available
     */
    private func createFallbackCoin(from searchItem: RecentSearchItem) -> Coin {
        // Create a coin object with basic quote structure to prevent crashes
        // This is a fallback when the full coin data is not available in cache
        
        // Create a basic quote structure to prevent nil access crashes
        let basicQuote = Quote(
            price: 0.0,
            volume24h: nil,
            volumeChange24h: nil,
            percentChange1h: nil,
            percentChange24h: nil,
            percentChange7d: nil,
            percentChange30d: nil,
            percentChange60d: nil,
            percentChange90d: nil,
            marketCap: nil,
            marketCapDominance: nil,
            fullyDilutedMarketCap: nil,
            lastUpdated: nil
        )
        
        let quotes = ["USD": basicQuote]
        
        // Use saved slug if available, otherwise map symbol to CoinGecko ID
        let geckoSlug = searchItem.slug ?? symbolToGeckoId(searchItem.symbol)
        
        return Coin(
            id: searchItem.coinId,
            name: searchItem.name,
            symbol: searchItem.symbol,
            slug: geckoSlug,
            numMarketPairs: 0,
            dateAdded: nil,
            tags: nil,
            maxSupply: nil,
            circulatingSupply: nil,
            totalSupply: nil,
            infiniteSupply: nil,
            cmcRank: 9999, // Use high rank to indicate unknown
            lastUpdated: nil,
            quote: quotes // Basic quote structure to prevent crashes
        )
    }
    
    /**
     * Map common cryptocurrency symbols to their CoinGecko IDs
     */
    private func symbolToGeckoId(_ symbol: String) -> String {
        let symbolMap: [String: String] = [
            "BTC": "bitcoin",
            "ETH": "ethereum", 
            "BNB": "binancecoin",
            "XRP": "ripple",
            "ADA": "cardano",
            "DOGE": "dogecoin",
            "SOL": "solana",
            "TRX": "tron",
            "MATIC": "polygon",
            "DOT": "polkadot",
            "LTC": "litecoin",
            "SHIB": "shiba-inu",
            "AVAX": "avalanche-2",
            "ATOM": "cosmos",
            "UNI": "uniswap",
            "LINK": "chainlink",
            "BCH": "bitcoin-cash",
            "XLM": "stellar",
            "ALGO": "algorand",
            "VET": "vechain",
            "ICP": "internet-computer",
            "FIL": "filecoin",
            "ETC": "ethereum-classic",
            "HBAR": "hedera-hashgraph",
            "NEAR": "near",
            "APT": "aptos",
            "QNT": "quant-network",
            "XMR": "monero",
            "GRT": "the-graph",
            "LDO": "lido-dao"
        ]
        
        return symbolMap[symbol.uppercased()] ?? symbol.lowercased()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension SearchVC: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width, height: 80)
    }
} 