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
    private var searchBarComponent: SearchBarComponent!
    private let viewModel: SearchVM
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<SearchSection, Coin>!
    
    // MARK: - Scroll View Properties
    
    private var mainScrollView: UIScrollView!
    private var scrollContentView: UIView!
    
    // MARK: - Recent Searches Properties
    
    private var recentSearchesContainer: UIView!
    private var recentSearchesScrollView: UIScrollView!
    private var recentSearchesStackView: UIStackView!
    private var recentSearchesLabel: UILabel!
    private var clearRecentSearchesButton: UIButton!
    private let recentSearchManager = RecentSearchManager.shared
    
    // MARK: - Popular Coins Properties
    
    private var popularCoinsContainer: UIView!
    private var popularCoinsHeaderView: PopularCoinsHeaderView!
    private var popularCoinsCollectionView: UICollectionView!
    private var popularCoinsDataSource: UICollectionViewDiffableDataSource<SearchSection, Coin>!
    private var popularCoinsHeightConstraint: NSLayoutConstraint!
    // Removed: Now using skeleton screens for loading states
    private var isPopularCoinsLoading = false // Track loading state to prevent height conflicts
    
    // MARK: - Dynamic Constraints
    
    // Popular coins positioning constraints
    private var popularCoinsTopWithRecentSearches: NSLayoutConstraint!
    private var popularCoinsTopWithoutRecentSearches: NSLayoutConstraint!
    
    // MARK: - Navigation Properties
    
    private var shouldPresentKeyboardOnLoad = false
    private var hasAppeared = false
    private var emptyStateView: UIView?
    
    // MARK: - Search State
    
    private var currentSearchResults: [Coin] = [] // Track current search results for saving recent searches
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts SearchVM for better testability and modularity.
     * Uses dependency container for default instance.
     */
    init(viewModel: SearchVM = Dependencies.container.searchViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    /**
     * OBJECTIVE-C COMPATIBILITY INITIALIZER
     * 
     * Convenience initializer for Objective-C compatibility.
     * Uses default dependency injection setup.
     */
    override convenience init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.init(viewModel: Dependencies.container.searchViewModel())
    }
    
    /**
     * PLAIN INIT FOR OBJECTIVE-C
     * 
     * Simple convenience initializer for [[ViewController alloc] init] pattern.
     */
    convenience init() {
        self.init(viewModel: Dependencies.container.searchViewModel())
    }
    
    required init?(coder: NSCoder) {
        self.viewModel = Dependencies.container.searchViewModel()
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureSearchBar()
        configureRecentSearches()
        configurePopularCoins()
        configureCollectionView()
        configureDataSource()
        bindViewModel()
        setupEmptyState()
        loadRecentSearches()
        
        // Set initial state to show popular coins
        showPopularCoins(true)
        collectionView.isHidden = true
        
        // Trigger initial popular coins data load
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            AppLogger.ui("SearchVC: viewDidLoad - triggering initial popular coins load")
            self.viewModel.updatePopularCoinsFilter(.topGainers) // This will use cache or fetch fresh data
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh recent searches when returning to search
        loadRecentSearches()
        
        // Maintain the current state - if no search is active, show popular coins
        let currentSearchText = searchBarComponent.text ?? ""
        if currentSearchText.isEmpty {
            // No active search - show popular coins (not recent searches)
            let hasRecentSearches = !recentSearchManager.getRecentSearchItems().isEmpty
            showRecentSearches(hasRecentSearches)
            showPopularCoins(true)
            collectionView.isHidden = true // Keep main collection view hidden
            
            // Update popular coins position based on recent searches
            updatePopularCoinsPosition(hasRecentSearches: hasRecentSearches)
            
            // Force layout update and reload popular coins data
            view.layoutIfNeeded()
            popularCoinsCollectionView.reloadData()
        }
        
        // Setup but don't present keyboard yet - wait for viewDidAppear
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Present keyboard if coming from search icon (not tab bar) and this is first appearance
        if shouldPresentKeyboardOnLoad && !hasAppeared {
            hasAppeared = true
            // Use longer delay for simulator compatibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.searchBarComponent.becomeFirstResponder()
            }
            shouldPresentKeyboardOnLoad = false
        }
        
        // Ensure popular coins are properly displayed if no search is active
        let currentSearchText = searchBarComponent.text ?? ""
        if currentSearchText.isEmpty {
            AppLogger.ui("SearchVC: viewDidAppear - ensuring popular coins are displayed")
            // Force layout update and ensure popular coins fill the space
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.view.layoutIfNeeded()
                self.popularCoinsCollectionView.reloadData()
                
                // Only fetch fresh data if we don't have any data or if cache is old
                let currentCoins = self.viewModel.currentPopularCoins
                if currentCoins.isEmpty {
                    let currentFilter = self.viewModel.currentPopularCoinsState.selectedFilter
                    AppLogger.ui("SearchVC: viewDidAppear - no data available, fetching fresh popular coins for \(currentFilter.displayName)")
                    self.viewModel.fetchFreshPopularCoins(for: currentFilter)
                } else {
                    AppLogger.ui("SearchVC: viewDidAppear - popular coins data already available (\(currentCoins.count) coins)")
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Dismiss keyboard when leaving
        searchBarComponent.resignFirstResponder()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update popular coins container border color for dark mode
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            popularCoinsContainer?.layer.borderColor = UIColor.systemGray5.cgColor
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Child ViewController Timer Management
    
    func stopBackgroundOperationsFromChild() {
        // Called by CoinDetailsVC to stop any background operations
        viewModel.cancelAllRequests()
        AppLogger.performance("SearchVC: Stopped background operations from child request")
    }
    
    func resumeBackgroundOperationsFromChild() {
        // Called by CoinDetailsVC when returning - can restart operations if needed
        AppLogger.performance("SearchVC: Resumed background operations from child request")
        // Note: Search doesn't have continuous background operations to resume
        // The search functionality is reactive and will work when needed
        
        // Ensure search functionality is working by checking if data is available
        if viewModel.cachedCoins.isEmpty {
            AppLogger.search("SearchVC: Refreshing search data after returning from child")
            viewModel.refreshSearchData()
        }
    }
    
    // MARK: - UI Setup
    
    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Search"
        
        // Use per-VC large title control (best practice)
        navigationItem.largeTitleDisplayMode = .always
        
        // Create main scroll view for entire page
        mainScrollView = UIScrollView()
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.showsVerticalScrollIndicator = true
        mainScrollView.showsHorizontalScrollIndicator = false
        mainScrollView.keyboardDismissMode = .onDrag
        view.addSubview(mainScrollView)
        
        // Content view that will hold all our content
        scrollContentView = UIView()
        scrollContentView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(scrollContentView)
        
        // Setup scroll view constraints - IMPORTANT: respect safe area and tab bar
        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), // Respects tab bar
            
            // Content view sizing
            scrollContentView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
    }
    
    private func configureSearchBar() {
        searchBarComponent = SearchBarComponent(placeholder: "Search cryptocurrencies...")
        searchBarComponent.delegate = self
        searchBarComponent.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure for full screen search usage
        searchBarComponent.configureForFullScreenSearch()
        
        scrollContentView.addSubview(searchBarComponent)
        
        NSLayoutConstraint.activate([
            searchBarComponent.topAnchor.constraint(equalTo: scrollContentView.topAnchor),
            searchBarComponent.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            searchBarComponent.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),
            searchBarComponent.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func configureRecentSearches() {
        // Container for recent searches
        recentSearchesContainer = UIView()
        recentSearchesContainer.translatesAutoresizingMaskIntoConstraints = false
        recentSearchesContainer.backgroundColor = .systemBackground
        recentSearchesContainer.isHidden = true // Hidden by default - no space when empty
        scrollContentView.addSubview(recentSearchesContainer)
        
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
            recentSearchesContainer.topAnchor.constraint(equalTo: searchBarComponent.bottomAnchor, constant: 8),
            recentSearchesContainer.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor),
            recentSearchesContainer.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor),
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
    
    private func configurePopularCoins() {
        // Header view with filter buttons (outside the bordered container)
        popularCoinsHeaderView = PopularCoinsHeaderView()
        popularCoinsHeaderView.delegate = self
        popularCoinsHeaderView.translatesAutoresizingMaskIntoConstraints = false
        scrollContentView.addSubview(popularCoinsHeaderView)
        
        // Container for popular coins list only (with styled border)
        popularCoinsContainer = UIView()
        popularCoinsContainer.translatesAutoresizingMaskIntoConstraints = false
        popularCoinsContainer.backgroundColor = .systemBackground
        popularCoinsContainer.isHidden = false // Always visible when search text is empty
        
        // Add border styling with proper dark mode support
        popularCoinsContainer.layer.cornerRadius = 12
        popularCoinsContainer.layer.borderWidth = 1
        popularCoinsContainer.layer.borderColor = UIColor.systemGray5.cgColor // Lighter border color
        
        // Use pure white background for clean appearance
        popularCoinsContainer.backgroundColor = .systemBackground // Clean white background
        
        // Add subtle shadow for depth
        popularCoinsContainer.layer.shadowColor = UIColor.black.cgColor
        popularCoinsContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        popularCoinsContainer.layer.shadowRadius = 4
        popularCoinsContainer.layer.shadowOpacity = 0.05
        
        scrollContentView.addSubview(popularCoinsContainer)
        
        // Collection view for popular coins (NON-SCROLLABLE, expands to fit content)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.itemSize = CGSize(width: view.bounds.width - 64, height: 80) // Account for container margins
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        popularCoinsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        popularCoinsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        popularCoinsCollectionView.backgroundColor = .clear
        popularCoinsCollectionView.isScrollEnabled = false // DISABLE INTERNAL SCROLLING
        popularCoinsCollectionView.showsVerticalScrollIndicator = false
        popularCoinsCollectionView.register(CoinCell.self, forCellWithReuseIdentifier: CoinCell.reuseID())
        popularCoinsContainer.addSubview(popularCoinsCollectionView)
        
        // Configure popular coins data source
        popularCoinsDataSource = UICollectionViewDiffableDataSource<SearchSection, Coin>(
            collectionView: popularCoinsCollectionView
        ) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CoinCell.reuseID(),
                for: indexPath
            ) as? CoinCell else {
                return UICollectionViewCell()
            }
            
            let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }
            
            // Configure the cell with full layout for vertical popular coins list (no rank)
            cell.configure(
                withRank: 0, // Remove rank column for popular coins
                name: coin.symbol, // Keep using symbol for consistent display
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
        
        popularCoinsCollectionView.dataSource = popularCoinsDataSource
        popularCoinsCollectionView.delegate = self
        
        // Removed: Now using skeleton screens for loading states
        
        // Create dynamic top constraints for popular coins header positioning
        popularCoinsTopWithRecentSearches = popularCoinsHeaderView.topAnchor.constraint(equalTo: recentSearchesContainer.bottomAnchor, constant: 8)
        popularCoinsTopWithoutRecentSearches = popularCoinsHeaderView.topAnchor.constraint(equalTo: searchBarComponent.bottomAnchor, constant: 24)
        
        // Dynamic height constraint for expanding container
        popularCoinsHeightConstraint = popularCoinsContainer.heightAnchor.constraint(equalToConstant: 100) // Will be updated dynamically
        
        // Layout constraints with header outside the bordered container
        NSLayoutConstraint.activate([
            // Header view constraints (outside the border)
            popularCoinsHeaderView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor),
            popularCoinsHeaderView.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor),
            popularCoinsHeaderView.heightAnchor.constraint(equalToConstant: 60),
            
            // Container constraints with margins for the border (positioned below header)
            popularCoinsContainer.topAnchor.constraint(equalTo: popularCoinsHeaderView.bottomAnchor, constant: 8),
            popularCoinsContainer.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            popularCoinsContainer.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),
            popularCoinsHeightConstraint, // Dynamic height
            
            // IMPORTANT: Bottom constraint to establish scroll content height
            popularCoinsContainer.bottomAnchor.constraint(equalTo: scrollContentView.bottomAnchor, constant: -16),
            
            // Collection view constraints (fills the bordered container with proper padding)
            popularCoinsCollectionView.topAnchor.constraint(equalTo: popularCoinsContainer.topAnchor, constant: 12),
            popularCoinsCollectionView.leadingAnchor.constraint(equalTo: popularCoinsContainer.leadingAnchor, constant: 16),
            popularCoinsCollectionView.trailingAnchor.constraint(equalTo: popularCoinsContainer.trailingAnchor, constant: -16),
            popularCoinsCollectionView.bottomAnchor.constraint(equalTo: popularCoinsContainer.bottomAnchor, constant: -12),
            
            // Loading indicator constraints (centered in container)
            // Removed: Loading indicator constraints (now using skeleton screens)
        ])
        
        // Start with the constraint for no recent searches (popular coins pushed up)
        popularCoinsTopWithoutRecentSearches.isActive = true
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
        collectionView.isHidden = true // Hidden initially - search results will show when needed
        
        // Register cell
        collectionView.register(CoinCell.self, forCellWithReuseIdentifier: CoinCell.reuseID())
        
        view.addSubview(collectionView) // Add to main view, not scroll view (search results overlay)
        
        // Position search results to overlay the scroll view when active
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 64), // Below search bar
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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
                let currentSearchText = self?.searchBarComponent.text ?? ""
                self?.updateEmptyState(results, searchText: currentSearchText)
            }
            .store(in: &cancellables)
        
        // Bind loading state for popular coins
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                self.isPopularCoinsLoading = isLoading // Track loading state
                
                if isLoading {
                    // Show skeleton loading for popular coins collection view
                    SkeletonLoadingManager.showSkeletonInCollectionView(self.popularCoinsCollectionView, cellType: .coinCell, numberOfItems: 6)
                    self.popularCoinsHeaderView.setLoading(true) // Disable buttons during loading
                    AppLogger.ui("Popular Coins: Loading started")
                } else {
                    // Hide skeleton loading and restore data source for popular coins
                    SkeletonLoadingManager.dismissSkeletonFromCollectionView(self.popularCoinsCollectionView)
                    self.popularCoinsCollectionView.dataSource = self.popularCoinsDataSource
                    self.popularCoinsHeaderView.setLoading(false) // Re-enable buttons
                    AppLogger.ui("Popular Coins: Loading finished, skeleton dismissed")
                    
                    // Immediately apply any pending data updates
                    DispatchQueue.main.async {
                        let currentPopularCoins = self.viewModel.currentPopularCoins
                        AppLogger.ui("Popular Coins: Post-loading update with \(currentPopularCoins.count) coins")
                        
                        if !currentPopularCoins.isEmpty {
                            // Apply the current data now that skeleton is gone
                            self.updatePopularCoinsDataSource(currentPopularCoins)
                        } else {
                            // Handle empty state - set minimum height
                            self.updatePopularCoinsHeight(for: 0)
                            AppLogger.ui("Popular Coins: No data available, set minimum height")
                        }
                    }
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
        
        // Bind popular coins data
        viewModel.popularCoins
            .receive(on: DispatchQueue.main)
            .removeDuplicates() // Prevent duplicate updates
            .sink { [weak self] popularCoins in
                guard let self = self else { return }
                AppLogger.ui("Popular Coins: Received \(popularCoins.count) coins, loading: \(self.isPopularCoinsLoading)")
                self.updatePopularCoinsDataSource(popularCoins)
            }
            .store(in: &cancellables)
        
        // Bind popular coins state
        viewModel.popularCoinsState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.popularCoinsHeaderView.updatePopularCoinsState(state)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Source Updates
    
    private func updateDataSource(_ coins: [Coin]) {
        // Don't apply snapshot if skeleton loading is active
        guard !SkeletonLoadingManager.isShowingSkeleton(in: collectionView) else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<SearchSection, Coin>()
        snapshot.appendSections([.main])
        snapshot.appendItems(coins)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func updatePopularCoinsDataSource(_ coins: [Coin]) {
        // Don't apply snapshot if skeleton loading is active
        guard !SkeletonLoadingManager.isShowingSkeleton(in: popularCoinsCollectionView) else { 
            AppLogger.ui("Popular Coins: Deferring data update - skeleton is showing, will update when loading ends")
            return 
        }
        
        var snapshot = NSDiffableDataSourceSnapshot<SearchSection, Coin>()
        snapshot.appendSections([.main])
        snapshot.appendItems(coins)
        
        AppLogger.ui("Popular Coins: Applying snapshot with \(coins.count) items")
        popularCoinsDataSource.apply(snapshot, animatingDifferences: true) { [weak self] in
            guard let self = self else { return }
            
            // Update height based on actual item count  
            self.updatePopularCoinsHeight(for: coins.count)
            AppLogger.ui("Popular Coins: ✅ Successfully updated with \(coins.count) items and adjusted height")
        }
    }
    
    private func updatePopularCoinsHeight(for itemCount: Int) {
        let itemHeight: CGFloat = 80
        let topPadding: CGFloat = 12
        let bottomPadding: CGFloat = 12
        let minHeight: CGFloat = 100
        
        // Handle empty state properly
        let calculatedHeight: CGFloat
        if itemCount == 0 {
            calculatedHeight = minHeight // Set to minimum height for empty state
            AppLogger.ui("Popular Coins: Setting minimum height for empty state")
        } else {
            calculatedHeight = max(CGFloat(itemCount) * itemHeight + topPadding + bottomPadding, minHeight)
        }
        
        // Only update if height actually changed (prevents unnecessary animations)
        guard popularCoinsHeightConstraint.constant != calculatedHeight else {
            AppLogger.ui("Popular Coins: Height unchanged (\(calculatedHeight)pt), skipping update")
            return
        }
        
        // Update the constraint
        popularCoinsHeightConstraint.constant = calculatedHeight
        
        // Animate the change
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.view.layoutIfNeeded()
        }
        
        AppLogger.ui("Popular Coins: Container height updated to \(calculatedHeight)pt for \(itemCount) items")
    }
    
    // Removed forcePopularCoinsHeightUpdate - was causing race conditions
    // Height updates now happen directly in updatePopularCoinsDataSource
    
    // MARK: - Empty State
    
    private func setupEmptyState() {
        emptyStateView = createEmptyStateView(
            title: "Search Cryptocurrencies",
            message: "Enter a coin name or symbol to search",
            imageName: "magnifyingglass.circle"
        )
        emptyStateView?.isHidden = true
        scrollContentView.addSubview(emptyStateView!)
        
        NSLayoutConstraint.activate([
            emptyStateView!.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            emptyStateView!.centerYAnchor.constraint(equalTo: scrollContentView.centerYAnchor),
            emptyStateView!.leadingAnchor.constraint(greaterThanOrEqualTo: scrollContentView.leadingAnchor, constant: 40),
            emptyStateView!.trailingAnchor.constraint(lessThanOrEqualTo: scrollContentView.trailingAnchor, constant: -40)
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
    
    private func updateEmptyState(_ searchResults: [Coin], searchText: String) {
        if searchText.isEmpty {
            // No search text - show popular coins instead of empty state
            emptyStateView?.isHidden = true
            showPopularCoins(true)
            collectionView.isHidden = true
        } else if searchResults.isEmpty {
            // Search text but no results - show empty state
            emptyStateView?.isHidden = false
            showPopularCoins(false)
            collectionView.isHidden = true
        } else {
            // Search results available - hide empty state and popular coins
            emptyStateView?.isHidden = true
            showPopularCoins(false)
            collectionView.isHidden = false
        }
        
        // Update popular coins positioning when popular coins are visible
        if !popularCoinsContainer.isHidden {
            updatePopularCoinsPosition(hasRecentSearches: !recentSearchesContainer.isHidden)
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
            self?.updateEmptyState(self?.currentSearchResults ?? [], 
                                  searchText: self?.searchBarComponent.text ?? "")
            
            // Update popular coins positioning since recent searches are now empty
            self?.updatePopularCoinsPosition(hasRecentSearches: false)
            
            // Animate the position change
            UIView.animate(withDuration: 0.3) {
                self?.view.layoutIfNeeded()
            }
            
            AppLogger.search("User cleared all recent searches")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - SearchBarComponentDelegate

extension SearchVC: SearchBarComponentDelegate {
    func searchBarComponent(_ searchBar: SearchBarComponent, textDidChange searchText: String) {
        // Update the view model's search text which triggers the debounced search
        viewModel.updateSearchText(searchText)
        
        // Show/hide sections based on search text
        if searchText.isEmpty {
            let hasRecentSearches = !recentSearchManager.getRecentSearchItems().isEmpty
            showRecentSearches(hasRecentSearches)
            showPopularCoins(true) // Always show popular coins when no search text
            
            // Hide main collection view when showing popular coins
            collectionView.isHidden = true
        } else {
            showRecentSearches(false)
            showPopularCoins(false) // Hide popular coins during search
            
            // Show main collection view for search results
            collectionView.isHidden = false
        }
    }
    
    func searchBarComponentSearchButtonClicked(_ searchBar: SearchBarComponent) {
        searchBar.resignFirstResponder()
        
        // Save search term if it has results
        let searchText = searchBar.text ?? ""
        if !searchText.isEmpty && !currentSearchResults.isEmpty {
            saveRecentSearch(searchText)
        }
    }
    
    func searchBarComponentCancelButtonClicked(_ searchBar: SearchBarComponent) {
        viewModel.clearSearch()
        
        // Show sections when canceling
        let hasRecentSearches = !recentSearchManager.getRecentSearchItems().isEmpty
        showRecentSearches(hasRecentSearches)
        showPopularCoins(true) // Show popular coins when canceling search
        
        // Hide main collection view when showing popular coins
        collectionView.isHidden = true
    }
}

// MARK: - PopularCoinsHeaderViewDelegate

extension SearchVC: PopularCoinsHeaderViewDelegate {
    func popularCoinsHeaderView(_ headerView: PopularCoinsHeaderView, didSelectFilter filter: PopularCoinsFilter) {
        AppLogger.search("Popular Coins: User selected \(filter.displayName)")
        viewModel.updatePopularCoinsFilter(filter)
    }
}

// MARK: - UICollectionViewDelegate

extension SearchVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        // Dismiss keyboard
        searchBarComponent.resignFirstResponder()
        
        let selectedCoin: Coin
        
        if collectionView == self.collectionView {
            // Main search results collection view
            selectedCoin = currentSearchResults[indexPath.item]
            AppLogger.search("Search: User tapped on search result: \(selectedCoin.symbol)")
            
            // Save this as a recent search since user selected it from search results
            let logoUrl = viewModel.currentCoinLogos[selectedCoin.id]
            recentSearchManager.addRecentSearch(
                coinId: selectedCoin.id,
                symbol: selectedCoin.symbol,
                name: selectedCoin.name,
                logoUrl: logoUrl,
                slug: selectedCoin.slug
            )
        } else if collectionView == popularCoinsCollectionView {
            // Popular coins collection view
            selectedCoin = viewModel.currentPopularCoins[indexPath.item]
            AppLogger.search("Popular Coins: User tapped on popular coin: \(selectedCoin.symbol)")
            
            // Don't add popular coins to recent searches - they're separate sections
            // Popular coins stay persistent and don't get affected by user interactions
        } else {
            return
        }
        
        // 🌐 TRY TO GET FRESH DATA: Check SharedCoinDataManager for most recent prices
        let sharedCoins = Dependencies.container.sharedCoinDataManager().currentCoins
        let coinToNavigateTo: Coin
        if let freshCoin = sharedCoins.first(where: { $0.id == selectedCoin.id }) {
            AppLogger.data("Using FRESH coin data for \(selectedCoin.symbol) from SharedCoinDataManager")
            coinToNavigateTo = freshCoin
        } else {
            AppLogger.data("Using selected coin data for \(selectedCoin.symbol) (not in SharedCoinDataManager)", level: .warning)
            coinToNavigateTo = selectedCoin
        }
        
        let detailsVC = CoinDetailsVC(coin: coinToNavigateTo)
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
        AppLogger.search("Recent Searches: Found \(recentSearchItems.count) searches: \(recentSearchItems.map { $0.symbol })")
        displayRecentSearches(recentSearchItems)
        
        let hasRecentSearches = !recentSearchItems.isEmpty
        showRecentSearches(hasRecentSearches)
        
        // Update popular coins positioning based on recent searches availability
        if !collectionView.isHidden { // Only update if popular coins are currently visible
            updatePopularCoinsPosition(hasRecentSearches: hasRecentSearches)
        }
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
        
        AppLogger.search("Recent Searches: Displayed \(searchItems.count) buttons")
    }
    
    /**
     * Show or hide recent searches container
     */
    private func showRecentSearches(_ show: Bool) {
        // Update container visibility
        recentSearchesContainer.isHidden = !show
        
        // Update popular coins positioning based on recent searches visibility
        updatePopularCoinsPosition(hasRecentSearches: show)
        
        // Animate the layout change
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
        
        AppLogger.search("Recent Searches: \(show ? "Showing" : "Hiding") container")
    }
    
    /**
     * Update popular coins position based on recent searches visibility
     */
    private func updatePopularCoinsPosition(hasRecentSearches: Bool) {
        // Guard against nil constraints (safety check)
        guard let withRecentSearches = popularCoinsTopWithRecentSearches,
              let withoutRecentSearches = popularCoinsTopWithoutRecentSearches else {
            AppLogger.ui("Popular Coins: Position constraints not initialized yet", level: .warning)
            return
        }
        
        // Deactivate both constraints
        withRecentSearches.isActive = false
        withoutRecentSearches.isActive = false
        
        // Activate the appropriate constraint based on recent searches visibility
        if hasRecentSearches && !recentSearchesContainer.isHidden {
            withRecentSearches.isActive = true
        } else {
            withoutRecentSearches.isActive = true
        }
        
        AppLogger.ui("Popular Coins: Position updated - Recent searches: \(hasRecentSearches)")
    }
    
    /**
     * Show or hide popular coins container
     */
    private func showPopularCoins(_ show: Bool) {
        // Simple visibility toggle - no constraint switching needed with scroll view
        popularCoinsContainer.isHidden = !show
        popularCoinsHeaderView.isHidden = !show
        
        // Update popular coins position based on recent searches visibility
        updatePopularCoinsPosition(hasRecentSearches: !recentSearchesContainer.isHidden)
        
        // Animate the layout change
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        }) { [weak self] _ in
            // Reload collection view after animation
            if show {
                self?.popularCoinsCollectionView.reloadData()
            }
        }
        
        AppLogger.ui("Popular Coins: \(show ? "Showing" : "Hiding") container")
    }
    
    /**
     * Handle recent search button tap - find real coin data and navigate
     */
    private func recentSearchButtonTapped(_ searchItem: RecentSearchItem) {
        AppLogger.search("Recent Search: Tapped \(searchItem.symbol) - finding fresh coin data")
        
        // 🌐 FIRST: Try to get fresh data from SharedCoinDataManager
        let sharedCoins = Dependencies.container.sharedCoinDataManager().currentCoins
        if let freshCoin = sharedCoins.first(where: { $0.id == searchItem.coinId }) {
            AppLogger.data("Found FRESH coin data for \(searchItem.symbol) from SharedCoinDataManager")
            let detailsVC = CoinDetailsVC(coin: freshCoin)
            navigationController?.pushViewController(detailsVC, animated: true)
            return
        }
        
        // FALLBACK: Try to find the coin in current search results
        if let cachedCoin = findCoinInCache(coinId: searchItem.coinId) {
            AppLogger.data("Using cached coin data for \(searchItem.symbol) (SharedCoinDataManager didn't have it)", level: .warning)
            let detailsVC = CoinDetailsVC(coin: cachedCoin)
            navigationController?.pushViewController(detailsVC, animated: true)
            return
        }
        
        // LAST RESORT: Search for the coin by symbol to get real data
                    AppLogger.search("Searching for \(searchItem.symbol) to get real coin data")
        searchForCoinAndNavigate(searchItem: searchItem)
    }
    
    /**
     * Search for a specific coin and navigate to its details when found - IMPROVED
     */
    private func searchForCoinAndNavigate(searchItem: RecentSearchItem) {
        // Store the original search text to restore later
        let originalSearchText = searchBarComponent.text ?? ""
        
        // First try to search in the search view model's cached data directly
        if let cachedCoin = findCoinBySymbolInCache(searchItem.symbol) {
                            AppLogger.search("Found coin in search cache: \(searchItem.symbol)")
            let detailsVC = CoinDetailsVC(coin: cachedCoin)
            navigationController?.pushViewController(detailsVC, animated: true)
            return
        }
        
        // If not in cache, trigger a live search
                    AppLogger.search("Triggering live search for \(searchItem.symbol)")
        searchBarComponent.text = searchItem.symbol
        viewModel.updateSearchText(searchItem.symbol)
        
        // Wait for search results with a more reliable approach
        var searchSubscription: AnyCancellable?
        
        searchSubscription = viewModel.searchResults
            .receive(on: DispatchQueue.main)
            .timeout(.seconds(5), scheduler: DispatchQueue.main) // Increased timeout to 5 seconds
            .sink(
                receiveCompletion: { [weak self] completion in
                    searchSubscription?.cancel()
                    
                    if case .failure = completion {
                        AppLogger.search("Search timeout for \(searchItem.symbol) - using fallback navigation", level: .warning)
                        self?.navigateWithFallback(searchItem: searchItem, fallbackText: originalSearchText)
                    }
                },
                receiveValue: { [weak self] searchResults in
                    guard let self = self else { 
                        searchSubscription?.cancel()
                        return 
                    }
                    
                    // Look for exact or close matches
                    let matchingCoin = self.findBestMatch(for: searchItem, in: searchResults)
                    
                    if let coin = matchingCoin {
                        searchSubscription?.cancel()
                                                    AppLogger.search("Found real coin data for \(searchItem.symbol)")
                        
                        // Restore original search text
                        self.searchBarComponent.text = originalSearchText
                        self.viewModel.updateSearchText(originalSearchText)
                        
                        // Navigate with real coin data
                        let detailsVC = CoinDetailsVC(coin: coin)
                        self.navigationController?.pushViewController(detailsVC, animated: true)
                    } else if !searchResults.isEmpty {
                        // If we have results but no exact match, wait a bit more
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if let betterMatch = self.findBestMatch(for: searchItem, in: searchResults) {
                                searchSubscription?.cancel()
                                self.searchBarComponent.text = originalSearchText
                                self.viewModel.updateSearchText(originalSearchText)
                                let detailsVC = CoinDetailsVC(coin: betterMatch)
                                self.navigationController?.pushViewController(detailsVC, animated: true)
                            } else {
                                searchSubscription?.cancel()
                                self.navigateWithFallback(searchItem: searchItem, fallbackText: originalSearchText)
                            }
                        }
                    }
                }
            )
    }
    
    /**
     * Fallback navigation when real coin data cannot be found - LAST RESORT ONLY
     */
    private func navigateWithFallback(searchItem: RecentSearchItem, fallbackText originalSearchText: String) {
        // Restore original search text
        searchBarComponent.text = originalSearchText
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
     * Find coin in cached search data - IMPROVED to look in multiple sources
     */
    private func findCoinInCache(coinId: Int) -> Coin? {
        // First check current search results
        if let coin = currentSearchResults.first(where: { $0.id == coinId }) {
            return coin
        }
        
        // Then check the search view model's cached coin data
        if let coin = viewModel.cachedCoins.first(where: { $0.id == coinId }) {
            return coin
        }
        
        // Finally check the persistence service for main coin list cache
        if let cachedCoins = PersistenceService.shared.loadCoinList(),
           let coin = cachedCoins.first(where: { $0.id == coinId }) {
            return coin
        }
        
        return nil
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
    
    /**
     * Find coin by symbol in all available cached data sources
     */
    private func findCoinBySymbolInCache(_ symbol: String) -> Coin? {
        let lowercaseSymbol = symbol.lowercased()
        
        // Check search view model cache
        if let coin = viewModel.cachedCoins.first(where: { $0.symbol.lowercased() == lowercaseSymbol }) {
            return coin
        }
        
        // Check persistence service main cache
        if let cachedCoins = PersistenceService.shared.loadCoinList(),
           let coin = cachedCoins.first(where: { $0.symbol.lowercased() == lowercaseSymbol }) {
            return coin
        }
        
        return nil
    }
    
    /**
     * Find the best matching coin for a search item
     */
    private func findBestMatch(for searchItem: RecentSearchItem, in searchResults: [Coin]) -> Coin? {
        // First try exact ID match
        if let exactIdMatch = searchResults.first(where: { $0.id == searchItem.coinId }) {
            return exactIdMatch
        }
        
        // Then try exact symbol match
        let lowercaseSymbol = searchItem.symbol.lowercased()
        if let exactSymbolMatch = searchResults.first(where: { $0.symbol.lowercased() == lowercaseSymbol }) {
            return exactSymbolMatch
        }
        
        // Then try exact name match
        let lowercaseName = searchItem.name.lowercased()
        if let exactNameMatch = searchResults.first(where: { $0.name.lowercased() == lowercaseName }) {
            return exactNameMatch
        }
        
        // Finally try partial name match
        if let partialMatch = searchResults.first(where: { 
            $0.name.lowercased().contains(lowercaseName) || lowercaseName.contains($0.name.lowercased())
        }) {
            return partialMatch
        }
        
        return nil
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension SearchVC: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Both main search results and popular coins use full width
        return CGSize(width: view.bounds.width, height: 80)
    }
} 