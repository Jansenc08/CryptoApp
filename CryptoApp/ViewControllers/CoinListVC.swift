import UIKit
import Combine

final class CoinListVC: UIViewController, UIGestureRecognizerDelegate {
    
    // MARK: - Section Enum for Diffable Data Source

    enum CoinSection {
        case main
    }
    
    // MARK: - Properties
    
    var collectionView: UICollectionView!                                   // The collection view displaying coin data
    let viewModel = CoinListVM()                                            // The view model powering this screen
    var cancellables = Set<AnyCancellable>()                                // Stores Combine subscriptions
    var dataSource: UICollectionViewDiffableDataSource<CoinSection, Coin>!  // Data source for applying snapshots
    
    let imageCache = NSCache<NSString, UIImage>()                           // Optional image cache for coin logos
    let refreshControl = UIRefreshControl()                                 // Pull-to-refresh controller
    private var segmentControl: SegmentControl!                             // Segment control for Coins/Watchlist tabs
    private var coinsContainerView: UIView!                                 // Container for coins tab content
    private var watchlistContainerView: UIView!                             // Container for watchlist tab content
    private var watchlistVC: WatchlistVC!                                   // Watchlist view controller
    private var filterHeaderView: FilterHeaderView!                         // Filter buttons container
    private var sortHeaderView: SortHeaderView!                             // Sort column headers
    
    var autoRefreshTimer: Timer?                                            // Timer to refresh visible cells every few seconds
    let autoRefreshInterval: TimeInterval = 15                              //  Interval: 15 seconds
    
    // MARK: - Optimization Properties
    
    private var isRefreshing = false                                        // Track if refresh is in progress
    private var lastAutoRefreshTime: Date?                                  // Track last auto-refresh time
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureCollectionView()
        configureDataSource()
        bindViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Only fetch data on initial load, not on every view appear
        // Pull-to-refresh and auto-refresh handle data updates
        if viewModel.currentCoins.isEmpty {
            print("📱 Initial load - fetching data")
            viewModel.fetchCoins()
        } else {
            print("📱 View appeared - data already loaded, skipping fetch")
        }
        
        startAutoRefresh()     // Start auto-refreshing price updates
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAutoRefresh() //  Stop Timer immediately when transition starts
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Only cancel API calls if we're actually leaving (not just a partial swipe)
        if isMovingFromParent || isBeingDismissed {
            viewModel.cancelAllRequests()
            print("🚪 Officially leaving coin list page - cancelled all API calls")
        } else {
            print("🔄 Transition cancelled - staying on coin list page")
        }
    }
    
    deinit {
        print("🧹 CoinListVC deinit - cleaning up resources")
        stopAutoRefresh()
        cancellables.removeAll()
    }
    
    
    // MARK: - UI Setup
    
    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Markets"
        setupNavigationItems()
        setupSegmentControl()
        setupContainerViews()
        setupFilterHeaderView()
        setupSortHeaderView()
    }
    
    private func setupFilterHeaderView() {
        filterHeaderView = FilterHeaderView()
        filterHeaderView.delegate = self
        filterHeaderView.translatesAutoresizingMaskIntoConstraints = false
        coinsContainerView.addSubview(filterHeaderView)
        
        NSLayoutConstraint.activate([
            filterHeaderView.topAnchor.constraint(equalTo: coinsContainerView.topAnchor),
            filterHeaderView.leadingAnchor.constraint(equalTo: coinsContainerView.leadingAnchor),
            filterHeaderView.trailingAnchor.constraint(equalTo: coinsContainerView.trailingAnchor)
        ])
    }
    
    private func setupSortHeaderView() {
        sortHeaderView = SortHeaderView()
        sortHeaderView.delegate = self
        sortHeaderView.translatesAutoresizingMaskIntoConstraints = false
        coinsContainerView.addSubview(sortHeaderView)
        
        NSLayoutConstraint.activate([
            sortHeaderView.topAnchor.constraint(equalTo: filterHeaderView.bottomAnchor),
            sortHeaderView.leadingAnchor.constraint(equalTo: coinsContainerView.leadingAnchor),
            sortHeaderView.trailingAnchor.constraint(equalTo: coinsContainerView.trailingAnchor)
        ])
        
        // Update sort header with current filter state
        updateSortHeaderForCurrentFilter()
        
        // Ensure ViewModel and SortHeaderView start in sync
        syncViewModelWithSortHeader()
    }
    
    private func setupNavigationItems() {
        // Add search icon to the right of navigation bar
        let searchButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(searchButtonTapped)
        )
        searchButton.tintColor = .systemGreen
        
        navigationItem.rightBarButtonItem = searchButton
    }
    
    @objc private func searchButtonTapped() {
        // Create SearchVC and present it with keyboard
        let searchVC = SearchVC()
        searchVC.setShouldPresentKeyboard(true) // Auto-present keyboard when coming from icon
        
        // Present modally or push to navigation stack
        navigationController?.pushViewController(searchVC, animated: true)
    }
    
    private func setupSegmentControl() {
        segmentControl = SegmentControl(items: ["Coins", "Watchlist"])
        segmentControl.delegate = self
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentControl)
        
        NSLayoutConstraint.activate([
            segmentControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupContainerViews() {
        // Coins container view (contains existing filter + sort + collection view)
        coinsContainerView = UIView()
        coinsContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coinsContainerView)
        
        // Watchlist container view (hidden initially)
        watchlistContainerView = UIView()
        watchlistContainerView.backgroundColor = .systemBackground
        watchlistContainerView.translatesAutoresizingMaskIntoConstraints = false
        watchlistContainerView.isHidden = true
        view.addSubview(watchlistContainerView)
        
        NSLayoutConstraint.activate([
            // Coins container constraints
            coinsContainerView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 20),
            coinsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coinsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coinsContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Watchlist container constraints (same as coins container)
            watchlistContainerView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 20),
            watchlistContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            watchlistContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            watchlistContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Setup watchlist view controller
        setupWatchlistViewController()
        
        // Add pan gesture recognizers for swipe-to-switch functionality
        setupSwipeGestures()
    }
    
    private func setupWatchlistViewController() {
        // Create and add watchlist view controller as child
        watchlistVC = WatchlistVC()
        addChild(watchlistVC)
        
        watchlistVC.view.translatesAutoresizingMaskIntoConstraints = false
        watchlistContainerView.addSubview(watchlistVC.view)
        
        NSLayoutConstraint.activate([
            watchlistVC.view.topAnchor.constraint(equalTo: watchlistContainerView.topAnchor),
            watchlistVC.view.leadingAnchor.constraint(equalTo: watchlistContainerView.leadingAnchor),
            watchlistVC.view.trailingAnchor.constraint(equalTo: watchlistContainerView.trailingAnchor),
            watchlistVC.view.bottomAnchor.constraint(equalTo: watchlistContainerView.bottomAnchor)
        ])
        
        watchlistVC.didMove(toParent: self)
    }
    
    private func setupSwipeGestures() {
        // Add pan gesture recognizer to coins container
        let coinsPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleContainerPan(_:)))
        coinsPanGesture.delegate = self
        coinsContainerView.addGestureRecognizer(coinsPanGesture)
        
        // Add pan gesture recognizer to watchlist container
        let watchlistPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleContainerPan(_:)))
        watchlistPanGesture.delegate = self
        watchlistContainerView.addGestureRecognizer(watchlistPanGesture)
    }
    
    @objc private func handleContainerPan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended else { return }
        
        let velocity = gesture.velocity(in: view)
        let translation = gesture.translation(in: view)
        
        // Determine swipe direction - need significant horizontal movement
        let minimumSwipeDistance: CGFloat = 50
        let minimumVelocity: CGFloat = 300
        
        let isSignificantHorizontalSwipe = abs(translation.x) > minimumSwipeDistance && abs(velocity.x) > minimumVelocity
        let isMainlyHorizontal = abs(translation.x) > abs(translation.y)
        
        guard isSignificantHorizontalSwipe && isMainlyHorizontal else { return }
        
        let currentIndex = segmentControl.selectedSegmentIndex
        
        if translation.x > 0 { // Swipe right - go to previous tab
            if currentIndex > 0 {
                let newIndex = currentIndex - 1
                segmentControl.setSelectedSegmentIndex(newIndex, animated: true)
                switchToTab(newIndex)
            }
        } else { // Swipe left - go to next tab
            if currentIndex < 1 { // We have 2 tabs (0 and 1)
                let newIndex = currentIndex + 1
                segmentControl.setSelectedSegmentIndex(newIndex, animated: true)
                switchToTab(newIndex)
            }
        }
    }
    
    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.bounds.width, height: 80)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        
        // Used so the CollectionView knows what identifier to associate with custom cell class
        collectionView.register(CoinCell.self, forCellWithReuseIdentifier: CoinCell.reuseID())
        collectionView.backgroundColor = .systemBackground
        coinsContainerView.addSubview(collectionView)
        
        // Pull to refresh
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: sortHeaderView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: coinsContainerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: coinsContainerView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: coinsContainerView.bottomAnchor)
        ])
    }
    
    // MARK: - Pull to Refresh

    @objc func handleRefresh() {
        print("\n🔄 Pull-to-Refresh | User initiated refresh")
        
        // Prevent multiple concurrent refreshes
        guard !isRefreshing else {
            print("🚫 Pull-to-Refresh | Already refreshing - cancelled")
            refreshControl.endRefreshing()
            return
        }
        
        isRefreshing = true
        print("✅ Pull-to-Refresh | Starting data fetch...")
        
        // Debug: Print sort state before refresh
        print("🔍 Pull-to-refresh - Before fetch:")
        print("  UI: \(sortHeaderView.currentSortColumn) \(sortHeaderView.currentSortOrder == .descending ? "DESC" : "ASC")")
        print("  VM: \(viewModel.getCurrentSortColumn()) \(viewModel.getCurrentSortOrder() == .descending ? "DESC" : "ASC")")
        
        viewModel.fetchCoins(onFinish: {
            print("🏁 Pull-to-Refresh | Data fetch completed")
            
            // Debug: Print sort state after refresh
            print("🔍 Pull-to-refresh - After fetch:")
            print("  VM: \(self.viewModel.getCurrentSortColumn()) \(self.viewModel.getCurrentSortOrder() == .descending ? "DESC" : "ASC")")
            
            self.isRefreshing = false
            self.refreshControl.endRefreshing()
            
            // Sync SortHeaderView UI with ViewModel's current sort state
            self.syncSortHeaderWithViewModel()
            
            print("🎯 Pull-to-Refresh | Spinner stopped, refresh complete")
        })
    }
    
    // MARK: - Diffable Data Source Setup
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<CoinSection, Coin>(collectionView: collectionView) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoinCell.reuseID(), for: indexPath) as? CoinCell else {
                return UICollectionViewCell()
            }
            
            let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }
            let currentFilter = self?.viewModel.currentFilterState.priceChangeFilter ?? .twentyFourHours
            
            // Configure the cell with dynamic percentage change based on current filter
            cell.configure(
                withRank: coin.cmcRank,
                name: coin.symbol,
                price: coin.priceString,
                market: coin.marketSupplyString,
                percentChange24h: coin.percentChangeString(for: currentFilter), // Now uses current filter
                sparklineData: sparklineNumbers,
                isPositiveChange: coin.isPositiveChange(for: currentFilter)     // Also uses current filter
            )
            
            // Load the coin logo image if available
            if let urlString = self?.viewModel.currentCoinLogos[coin.id] {
                // Removed verbose logo loading logs - only log if debugging needed
                // print("🖼️ CoinListVC | Loading logo for \(coin.name) (ID: \(coin.id)): \(urlString)")
                cell.coinImageView.downloadImage(fromURL: urlString)
            } else {
                // Only log missing logos for top coins (helps identify data issues)
                if coin.cmcRank <= 50 {
                    print("❌ CoinListVC | No logo URL for top coin \(coin.name) (Rank: \(coin.cmcRank), ID: \(coin.id))")
                }
                cell.coinImageView.setPlaceholder()
            }
            
            return cell
        }
        
        collectionView.dataSource = dataSource
    }
    
    // MARK: - ViewModel Bindings with Combine

    // Combine handles threading
    // Combines listens for changes to ui updates such as coins. (now using AnyPublisher)
    // even if data comes from the background thread, it sends it back on the main thread
    // handles async-queue switching
    // Combine uses GCD queues
    private func bindViewModel() {
        // Bind coin list changes
        viewModel.coins
            .receive(on: DispatchQueue.main) // ensures UI updates happens on the main thread
            .sink { [weak self] coins in // Creates a combine subscription
                var snapshot = NSDiffableDataSourceSnapshot<CoinSection, Coin>()
                snapshot.appendSections([.main])
                snapshot.appendItems(coins)
                self?.dataSource.apply(snapshot, animatingDifferences: true)
            }
            .store(in: &cancellables) // Keeps this subscription alive
        
        // Bind logo updates (e.g fetched after coin data)
        viewModel.coinLogos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        // Bind error message to show alert
        viewModel.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(title: "Error", message: error)
            }
            .store(in: &cancellables)
        
        // Bind price updates - only update cells that actually changed
        viewModel.updatedCoinIds
            .receive(on: DispatchQueue.main)
            .filter { !$0.isEmpty }  // Only process when there are actual changes
            .sink { [weak self] updatedCoinIds in
                self?.updateCellsForChangedCoins(updatedCoinIds)
            }
            .store(in: &cancellables)
        
        // Bind loading state to show/hide LoadingView in collection view
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                if isLoading {
                    // Show LoadingView in the collection view area
                    LoadingView.show(in: self.collectionView)
                    print("🔄 Loading | Showing spinner in collection view")
                } else {
                    // Hide LoadingView from collection view
                    LoadingView.dismiss(from: self.collectionView)
                    print("✅ Loading | Hiding spinner from collection view")
                }
            }
            .store(in: &cancellables)
    }
    
    private func showAlert(title: String, message: String) {
        // Reusable alert dialog for errors
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alert, animated: true)
    }
    
    private func showWatchlistFeedback(message: String, isAdding: Bool) {
        // Create a toast-like feedback view
        let feedbackView = UIView()
        feedbackView.backgroundColor = isAdding ? .systemGreen : .systemOrange
        feedbackView.layer.cornerRadius = 8
        feedbackView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: isAdding ? "star.fill" : "star.slash"))
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [imageView, label])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        feedbackView.addSubview(stackView)
        view.addSubview(feedbackView)
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),
            
            stackView.topAnchor.constraint(equalTo: feedbackView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: feedbackView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: feedbackView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: feedbackView.bottomAnchor, constant: -12),
            
            feedbackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // Animate the feedback view
        feedbackView.alpha = 0
        feedbackView.transform = CGAffineTransform(translationX: 0, y: 50)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            feedbackView.alpha = 1
            feedbackView.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseIn) {
                feedbackView.alpha = 0
                feedbackView.transform = CGAffineTransform(translationX: 0, y: -50)
            } completion: { _ in
                feedbackView.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Auto-Refresh Logic
    // The timer runs independently every 15 seconds
    // It triggers viewModel.fetchPriceUpdatesForVisibleCoins(...)
    // The fetch logic inside the view model runs asynchronously, updates only visible prices
    // After fetching, the Combine publisher emits new prices, which trigger targeted UI updates

    private func startAutoRefresh() {
        stopAutoRefresh() // clear any existing timer
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshVisibleCells()
        }
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    // MARK: - Child ViewController Timer Management
    
    func stopAutoRefreshFromChild() {
        // Called by CoinDetailsVC to stop background auto-refresh
        stopAutoRefresh()
        print("⏸️ CoinListVC: Stopped auto-refresh from child request")
    }
    
    func resumeAutoRefreshFromChild() {
        // Called by CoinDetailsVC when returning to resume auto-refresh
        startAutoRefresh()
        print("🔄 CoinListVC: Resumed auto-refresh from child request")
    }
    
    func stopWatchlistTimersFromChild() {
        // Stop the embedded WatchlistVC timers
        watchlistVC?.stopPeriodicUpdatesFromParent()
        print("⏸️ CoinListVC: Stopped watchlist timers from child request")
    }
    
    func resumeWatchlistTimersFromChild() {
        // Resume the embedded WatchlistVC timers
        watchlistVC?.resumePeriodicUpdatesFromParent()
        print("🔄 CoinListVC: Resumed watchlist timers from child request")
    }
    
    // Timer throttled to prevent API spam
    private func refreshVisibleCells() {
        
        // Avoid overlapping refreshes
        // - If data is already loading (initial load or pagination)
        // - Or if another refresh (pull-to-refresh or timer) is already in progress
        // => Skip this cycle to prevent multiple concurrent fetches
        guard !viewModel.currentIsLoading && !isRefreshing else { return }
        
        //  Throttle refreshes (rate-limiting)
        // - If the last refresh happened < 10 seconds ago, skip
        // - This prevents rapid, repeated API calls during quick scrolls or timer triggers
        if let lastRefresh = lastAutoRefreshTime,
           Date().timeIntervalSince(lastRefresh) < 10 {
            return
        }
        
        //  Mark that a refresh is in progress
        isRefreshing = true
        lastAutoRefreshTime = Date() // Update last refresh timestamp
        
        //  Determine which coins are currently visible on screen
        // - Only refresh prices for those visible coins (optimization)
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        let visibleCoinIds = visibleIndexPaths.compactMap { indexPath in
            viewModel.currentCoins[safe: indexPath.item]?.id
        }
        
        //   Trigger price update for visible coin IDs
        // - This calls a ViewModel method that fetches prices only for the listed coin IDs
        // - Once the update completes, mark refresh as finished
        print("\n🚀 Auto-Refresh | Starting price update cycle...")
        viewModel.fetchPriceUpdatesForVisibleCoins(visibleCoinIds) { [weak self] in
            self?.isRefreshing = false
        }
    }

    
    // MARK: - Optimized Price Update Logic
    // Updates Prices only if it changes otherwise no  
    private func updateCellsForChangedCoins(_ updatedCoinIds: Set<Int>) {
        // Skip if no changes
        guard !updatedCoinIds.isEmpty else { return }
        
        // Only update visible cells that actually changed
        var updatedCellsCount = 0
        
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let coin = viewModel.currentCoins[safe: indexPath.item],
                  updatedCoinIds.contains(coin.id),
                  let cell = collectionView.cellForItem(at: indexPath) as? CoinCell else { continue }
            
            let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }
            let currentFilter = viewModel.currentFilterState.priceChangeFilter
            
            // Update cell without reloading the whole list
            cell.updatePriceData(
                withPrice: coin.priceString,
                percentChange24h: coin.percentChangeString(for: currentFilter), // Now uses current filter
                sparklineData: sparklineNumbers,
                isPositiveChange: coin.isPositiveChange(for: currentFilter)     // Also uses current filter
            )
            
            updatedCellsCount += 1
        }
        
        if updatedCellsCount > 0 {
            print("🎨 UI Refresh | Updated \(updatedCellsCount) visible cells")
            print("═════════════════════════════════════════")
        }
        
        // Clear the updated coin IDs after processing
        viewModel.clearUpdatedCoinIds()
    }
    
    // MARK: - Filter Update Methods
    
    private func updateAllVisibleCellsForFilterChange() {
        // Update all visible cells when filter changes to show new percentage values
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let coin = viewModel.currentCoins[safe: indexPath.item],
                  let cell = collectionView.cellForItem(at: indexPath) as? CoinCell else { continue }
            
            let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }
            let currentFilter = viewModel.currentFilterState.priceChangeFilter
            
            cell.updatePriceData(
                withPrice: coin.priceString,
                percentChange24h: coin.percentChangeString(for: currentFilter),
                sparklineData: sparklineNumbers,
                isPositiveChange: coin.isPositiveChange(for: currentFilter)
            )
        }
    }

    // MARK: - Tab Management
    
    func switchToTab(_ index: Int) {
        segmentControl.setSelectedSegmentIndex(index, animated: true)
        segmentControl(segmentControl, didSelectSegmentAt: index)
    }
    
    private func updateSortHeaderForCurrentFilter() {
        let priceChangeTitle = viewModel.currentFilterState.priceChangeFilter.shortDisplayName + "%"
        sortHeaderView.updatePriceChangeColumnTitle(priceChangeTitle)
    }
    
        private func syncSortHeaderWithViewModel() {
        // Only sync if the states are different to avoid unnecessary updates
        if sortHeaderView.currentSortColumn != viewModel.getCurrentSortColumn() ||
           sortHeaderView.currentSortOrder != viewModel.getCurrentSortOrder() {
            sortHeaderView.currentSortColumn = viewModel.getCurrentSortColumn()
            sortHeaderView.currentSortOrder = viewModel.getCurrentSortOrder()
            sortHeaderView.updateSortIndicators()
            print("🔄 Synced sort header UI: \(viewModel.getCurrentSortColumn()) \(viewModel.getCurrentSortOrder() == .descending ? "DESC" : "ASC")")
        }
    }
    
    private func syncViewModelWithSortHeader() {
        // Ensure ViewModel starts with the same state as SortHeaderView
        let headerColumn = sortHeaderView.currentSortColumn
        let headerOrder = sortHeaderView.currentSortOrder
        
        if viewModel.getCurrentSortColumn() != headerColumn || viewModel.getCurrentSortOrder() != headerOrder {
            viewModel.updateSorting(column: headerColumn, order: headerOrder)
            print("🔧 Synced ViewModel with SortHeader: \(headerColumn) \(headerOrder == .descending ? "DESC" : "ASC")")
        }
    }

      // MARK: - Configuration
}

// MARK: - Scroll Pagination

extension CoinListVC: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Navigate to coin details screen when user taps a coin
        let selectedCoin = viewModel.currentCoins[indexPath.item]
        let detailsVC = CoinDetailsVC(coin: selectedCoin)
        navigationController?.pushViewController(detailsVC, animated: true)
        
                collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    // MARK: - Context Menu for Add to Watchlist
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let coin = viewModel.currentCoins[indexPath.item]
        let watchlistManager = WatchlistManager.shared
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            var actions: [UIAction] = []
            
            if watchlistManager.isInWatchlist(coinId: coin.id) {
                // Coin is already in watchlist - show remove option
                let removeAction = UIAction(
                    title: "Remove from Watchlist",
                    image: UIImage(systemName: "star.slash"),
                    attributes: .destructive
                ) { _ in
                    watchlistManager.removeFromWatchlist(coinId: coin.id)
                    self.showWatchlistFeedback(message: "Removed \(coin.symbol) from watchlist", isAdding: false)
                }
                actions.append(removeAction)
            } else {
                // Coin is not in watchlist - show add option
                let addAction = UIAction(
                    title: "Add to Watchlist",
                    image: UIImage(systemName: "star")
                ) { _ in
                    let logoURL = self.viewModel.currentCoinLogos[coin.id]
                    watchlistManager.addToWatchlist(coin, logoURL: logoURL)
                    self.showWatchlistFeedback(message: "Added \(coin.symbol) to watchlist", isAdding: true)
                }
                actions.append(addAction)
            }
            
            // Add view details action
            let detailsAction = UIAction(
                title: "View Details",
                image: UIImage(systemName: "info.circle")
            ) { _ in
                let detailsVC = CoinDetailsVC(coin: coin)
                self.navigationController?.pushViewController(detailsVC, animated: true)
            }
            actions.append(detailsAction)
            
            return UIMenu(title: coin.name, children: actions)
        }
    }
    
    // This function is called every time the user scrolls the collection view.
    // Implement infinite scroll thresholding with optimizations
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // Load more coins when scrolling near the bottom
        let offsetY = scrollView.contentOffset.y
        
        // The current vertical position the user has scrolled from the top.
        let contentHeight = scrollView.contentSize.height
        
        // The total height of the scrollable content (all coin cells combined).
        let height = scrollView.frame.size.height
        
        // Only proceed if we have content
        guard contentHeight > 0 else { return }
        
        // Calculate how far the user has scrolled as a percentage
        // Calculate scroll progress as a ratio:
        // (current scroll position from top + visible height) / total scrollable content height
        // This gives a value between 0.0 (top) and 1.0 (bottom).
        let scrollProgress = (offsetY + height) / contentHeight
        
        // If user has scrolled past 75% of the total content height, trigger pagination.
        // Balanced threshold for good UX while preventing excessive API calls
        if scrollProgress > 0.75 {
            print("📜 Scroll | Triggered pagination at \(String(format: "%.1f", scrollProgress * 100))%")
            viewModel.loadMoreCoins()
        }
    }
}

// MARK: - SortHeaderViewDelegate

extension CoinListVC: SortHeaderViewDelegate {
    func sortHeaderView(_ headerView: SortHeaderView, didSelect column: CryptoSortColumn, order: CryptoSortOrder) {
        print("🔄 Sort: Column \(column) | Order: \(order == .descending ? "Descending" : "Ascending")")
        viewModel.updateSorting(column: column, order: order)
    }
}

// MARK: - FilterHeaderViewDelegate

extension CoinListVC: FilterHeaderViewDelegate {
    func filterHeaderView(_ headerView: FilterHeaderView, didTapPriceChangeButton button: FilterButton) {
        let modalVC = FilterModalVC(filterType: .priceChange, currentState: viewModel.currentFilterState)
        modalVC.delegate = self
        present(modalVC, animated: true)
    }
    
    func filterHeaderView(_ headerView: FilterHeaderView, didTapTopCoinsButton button: FilterButton) {
        let modalVC = FilterModalVC(filterType: .topCoins, currentState: viewModel.currentFilterState)
        modalVC.delegate = self
        present(modalVC, animated: true)
    }
    
    func filterHeaderView(_ headerView: FilterHeaderView, didTapAddCoinsButton button: UIButton) {
        // Not needed for coin list page (only used in watchlist), but required for protocol conformance
        // Could optionally navigate to search or add functionality here if desired
    }
}

// MARK: - FilterModalVC Delegate

extension CoinListVC: FilterModalVCDelegate {
    func filterModalVC(_ modalVC: FilterModalVC, didSelectPriceChangeFilter filter: PriceChangeFilter) {
        print("🎯 Filter Selected: \(filter.displayName)")
        
        // Apply the filter - ViewModel will handle loading state and LoadingView will show automatically
        viewModel.updatePriceChangeFilter(filter)
        
        // Update header view state to reflect the new filter
        filterHeaderView.updateFilterState(viewModel.currentFilterState)
        updateSortHeaderForCurrentFilter() // Also update sort header
        updateAllVisibleCellsForFilterChange() // Update all visible cells for percentage change
    }
    
    func filterModalVC(_ modalVC: FilterModalVC, didSelectTopCoinsFilter filter: TopCoinsFilter) {
        print("🎯 Filter Selected: \(filter.displayName)")
        
        // Apply the filter - ViewModel will handle loading state and LoadingView will show automatically
        viewModel.updateTopCoinsFilter(filter)
        
        // Update header view state to reflect the new filter
        filterHeaderView.updateFilterState(viewModel.currentFilterState)
        updateSortHeaderForCurrentFilter() // Also update sort header
        updateAllVisibleCellsForFilterChange() // Update all visible cells for percentage change
    }
    
    func filterModalVCDidCancel(_ modalVC: FilterModalVC) {
        // Handle cancellation if needed
        print("Filter modal was cancelled")
    }
}

// MARK: - SegmentControlDelegate

extension CoinListVC: SegmentControlDelegate {
    func segmentControl(_ segmentControl: SegmentControl, didSelectSegmentAt index: Int) {
        print("🔄 Segment control selected index: \(index)")
        
        // Animate the container view transition
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            switch index {
            case 0: // Coins
                self.coinsContainerView.isHidden = false
                self.watchlistContainerView.isHidden = true
                self.navigationItem.title = "Markets"
                
            case 1: // Watchlist
                self.coinsContainerView.isHidden = true
                self.watchlistContainerView.isHidden = false
                self.navigationItem.title = "Watchlist"
                
            default:
                break
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension CoinListVC {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pan gestures to work simultaneously with collection view scroll gestures
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
