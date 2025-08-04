import UIKit
import Combine

final class CoinListVC: UIViewController, UIGestureRecognizerDelegate {
    
    // MARK: - Section Enum for Diffable Data Source

    enum CoinSection {
        case main
    }
    
    // MARK: - Properties
    
    var collectionView: UICollectionView!                                   // The collection view displaying coin data
    let viewModel: CoinListVM                                               // The view model powering this screen
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
    
    // MARK: - Empty State Properties
    private var emptyStateView: UIContentUnavailableView!                   // Empty state view for when no coins are available
    
    // MARK: - Back to Top Button
    private var backToTopButton: UIButton!                                  // Floating action button to scroll back to top
    
    var autoRefreshTimer: Timer?                                            // Timer to refresh visible cells every few seconds
    let autoRefreshInterval: TimeInterval = 15                              //  Interval: 15 seconds
    
    // MARK: - Optimization Properties
    
    private var isRefreshing = false                                        // Track if refresh is in progress
    private var lastAutoRefreshTime: Date?                                  // Track last auto-refresh time
    
    // MARK: - Sliding Gesture Properties
    
    private var currentPageIndex: Int = 0
    private var isTransitioning: Bool = false
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts CoinListVM for better testability and modularity.
     * Uses dependency container for default instance.
     */
    init(viewModel: CoinListVM = Dependencies.container.coinListViewModel()) {
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
        self.init(viewModel: Dependencies.container.coinListViewModel())
    }
    
    /**
     * PLAIN INIT FOR OBJECTIVE-C
     * 
     * Simple convenience initializer for [[ViewController alloc] init] pattern.
     */
    convenience init() {
        self.init(viewModel: Dependencies.container.coinListViewModel())
    }
    
    required init?(coder: NSCoder) {
        self.viewModel = Dependencies.container.coinListViewModel()
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureCollectionView()
        configureDataSource()
        configureEmptyState()
        bindViewModel()
        
        // Preload both tabs for seamless switching
        preloadAllTabData()
    }
    
    private func preloadAllTabData() {
        AppLogger.performance("🚀 Preloading all tab data for seamless experience")
        
        // SharedCoinDataManager handles all data loading automatically
        // No need to call viewModel.fetchCoins() - it will get data from shared manager
        
        // Preload watchlist data without showing loading state
        watchlistVC?.preloadDataSilently()
        
        AppLogger.performance("✅ Tab preloading initiated")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Data is already preloaded in viewDidLoad - just start timers
        AppLogger.performance("📱 CoinListVC appeared - data preloaded, starting timers only")
        
        // Start resources for the currently active tab only
        startResourcesForActiveTab()
    }
    
    private func startResourcesForActiveTab() {
        let currentIndex = segmentControl?.selectedSegmentIndex ?? 0
        
        // SharedCoinDataManager handles all updates now, so just log which tab is active
        if currentIndex == 0 {
            AppLogger.performance("Coins tab is active - using SharedCoinDataManager")
        } else {
            AppLogger.performance("Watchlist tab is active - using SharedCoinDataManager")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop all timers and resources when leaving the entire CoinListVC
        stopAutoRefresh()
        watchlistVC?.pausePeriodicUpdates()
        
        AppLogger.performance("Stopped all timers - leaving CoinListVC")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Only cancel API calls if we're actually leaving (not just a partial swipe)
        if isMovingFromParent || isBeingDismissed {
            viewModel.cancelAllRequests()
            AppLogger.performance("🚪 Officially leaving coin list page - cancelled all API calls")
        } else {
            AppLogger.performance("🔄 Transition cancelled - staying on coin list page")
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update button border color when switching between light/dark mode
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackToTopButtonAppearance()
        }
    }
    
    private func updateBackToTopButtonAppearance() {
        backToTopButton?.layer.borderColor = UIColor.systemGray4.cgColor
        backToTopButton?.layer.shadowColor = UIColor.label.cgColor
    }
    
    deinit {
        AppLogger.performance("🧹 CoinListVC deinit - cleaning up all resources")
        
        // Clean up all resources
        stopAutoRefresh()
        viewModel.cancelAllRequests()
        cancellables.removeAll()
        
        // Child view controllers are automatically cleaned up by the container
    }
    
    
    // MARK: - UI Setup
    
    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Markets"
        
        // Use per-VC large title control (best practice)
        navigationItem.largeTitleDisplayMode = .never
        
        setupNavigationItems()
        setupSegmentControl()
        setupContainerViews()
        setupFilterHeaderView()
        setupSortHeaderView()
        setupBackToTopButton()
        // setupSwipeGestures() is already called in setupContainerViews()
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
        
        // Watchlist container view (hidden initially)
        watchlistContainerView = UIView()
        watchlistContainerView.backgroundColor = .systemBackground
        watchlistContainerView.translatesAutoresizingMaskIntoConstraints = false
        watchlistContainerView.isHidden = true
        
        view.addSubviews(coinsContainerView, watchlistContainerView)
        
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
    
    private func setupBackToTopButton() {
        // Create a circular floating action button
        backToTopButton = UIButton(type: .system)
        backToTopButton.backgroundColor = .systemBackground
        backToTopButton.tintColor = .systemBlue
        backToTopButton.layer.cornerRadius = 25
        backToTopButton.layer.borderWidth = 1
        backToTopButton.layer.borderColor = UIColor.systemGray4.cgColor
        backToTopButton.layer.shadowColor = UIColor.label.cgColor
        backToTopButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        backToTopButton.layer.shadowOpacity = 0.2
        backToTopButton.layer.shadowRadius = 4
        backToTopButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the up arrow icon
        let chevronUp = UIImage(systemName: "chevron.up")
        backToTopButton.setImage(chevronUp, for: .normal)
        backToTopButton.imageView?.contentMode = .scaleAspectFit
        
        // Add target for tap action
        backToTopButton.addTarget(self, action: #selector(backToTopButtonTapped), for: .touchUpInside)
        
        // Start hidden
        backToTopButton.alpha = 0
        backToTopButton.isHidden = true
        
        // Add to the main view (not the container views so it shows on both tabs)
        view.addSubview(backToTopButton)
        
        // Set constraints
        NSLayoutConstraint.activate([
            backToTopButton.widthAnchor.constraint(equalToConstant: 50),
            backToTopButton.heightAnchor.constraint(equalToConstant: 50),
            backToTopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backToTopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func backToTopButtonTapped() {
        // Get the appropriate scroll view based on current tab
        let currentIndex = segmentControl?.selectedSegmentIndex ?? 0
        
        if currentIndex == 0 {
            // Coins tab - scroll collection view to top
            collectionView.setContentOffset(.zero, animated: true)
        } else {
            // Watchlist tab - let the watchlist VC handle scrolling to top
            watchlistVC?.scrollToTop()
        }
        
        // Hide the button after use since we're now at the top
        hideBackToTopButton()
    }
    
    private func showBackToTopButton() {
        guard backToTopButton.isHidden else { return }
        
        backToTopButton.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.backToTopButton.alpha = 1
            self.backToTopButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.backToTopButton.transform = .identity
            }
        }
    }
    
    private func hideBackToTopButton() {
        guard !backToTopButton.isHidden else { return }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.backToTopButton.alpha = 0
            self.backToTopButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            self.backToTopButton.isHidden = true
            self.backToTopButton.transform = .identity
        }
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
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .began:
            isTransitioning = true
            
            // Ensure both containers are visible for smooth transition
            coinsContainerView.isHidden = false
            watchlistContainerView.isHidden = false
            
        case .changed:
            // Only respond to horizontal gestures
            guard abs(translation.x) > abs(translation.y) else { return }
            
            // Calculate how much to move each container
            let offset = translation.x
            updateContainerPositions(offset: offset)
            
            // Update segment control underline in real-time
            updateSegmentControlProgress(offset: offset)
            
        case .ended, .cancelled:
            // Determine if we should switch pages based on distance and velocity
            let currentIndex = segmentControl.selectedSegmentIndex
            let shouldSwitch = shouldSwitchPage(translation: translation, velocity: velocity)
            
            if shouldSwitch {
                let newIndex = translation.x > 0 ? max(0, currentIndex - 1) : min(1, currentIndex + 1)
                if newIndex != currentIndex {
                    segmentControl.setSelectedSegmentIndex(newIndex, animated: true)
                    animateToPage(newIndex)
                    return
                }
            }
            
            // Snap back to current page if we didn't switch
            animateToPage(currentIndex)
            
        default:
            break
        }
    }
    
    private func shouldSwitchPage(translation: CGPoint, velocity: CGPoint) -> Bool {
        let minimumDistance: CGFloat = view.bounds.width * 0.3  // 30% of screen width
        let minimumVelocity: CGFloat = 500
        
        return abs(translation.x) > minimumDistance || abs(velocity.x) > minimumVelocity
    }
    
    private func updateContainerPositions(offset: CGFloat) {
        let currentIndex = segmentControl.selectedSegmentIndex
        let screenWidth = view.bounds.width
        
        if currentIndex == 0 { // Currently on Coins page
            // Coins container: moves left as we swipe left (to reveal Watchlist)
            coinsContainerView.transform = CGAffineTransform(translationX: offset, y: 0)
            // Watchlist container: starts off-screen right, moves in as we swipe left
            watchlistContainerView.transform = CGAffineTransform(translationX: screenWidth + offset, y: 0)
        } else { // Currently on Watchlist page
            // Watchlist container: moves right as we swipe right (to reveal Coins)
            watchlistContainerView.transform = CGAffineTransform(translationX: offset, y: 0)
            // Coins container: starts off-screen left, moves in as we swipe right
            coinsContainerView.transform = CGAffineTransform(translationX: -screenWidth + offset, y: 0)
        }
    }
    
    private func updateSegmentControlProgress(offset: CGFloat) {
        let screenWidth = view.bounds.width
        let currentIndex = segmentControl.selectedSegmentIndex
        
        // Calculate progress based on how far we've moved
        var progress: CGFloat = 0.0
        var fromIndex = currentIndex
        var toIndex = currentIndex
        
        if currentIndex == 0 { // Currently on Coins page
            if offset < 0 { // Swiping left (toward Watchlist)
                toIndex = 1
                progress = abs(offset) / screenWidth
            }
        } else { // Currently on Watchlist page
            if offset > 0 { // Swiping right (toward Coins)
                toIndex = 0
                progress = offset / screenWidth
            }
        }
        
        // Clamp progress to prevent overscroll effects
        progress = max(0.0, min(1.0, progress))
        
        // Only update if we're actually transitioning between segments
        if fromIndex != toIndex || progress > 0.0 {
            segmentControl.updateUnderlineProgress(fromSegment: fromIndex, toSegment: toIndex, withProgress: progress)
        }
    }
    

    
    // MARK: - Smooth Page Animation
    
    private func animateToPage(_ pageIndex: Int) {
        let screenWidth = view.bounds.width
        let animationDuration: TimeInterval = 0.35
        let springDamping: CGFloat = 0.8
        let springVelocity: CGFloat = 0.6
        
        currentPageIndex = pageIndex
        
        UIView.animate(withDuration: animationDuration, delay: 0, usingSpringWithDamping: springDamping, initialSpringVelocity: springVelocity, options: [.curveEaseOut, .allowUserInteraction]) {
            
            if pageIndex == 0 { // Animate to Coins page
                self.coinsContainerView.transform = .identity
                self.watchlistContainerView.transform = CGAffineTransform(translationX: screenWidth, y: 0)
            } else { // Animate to Watchlist page
                self.coinsContainerView.transform = CGAffineTransform(translationX: -screenWidth, y: 0)
                self.watchlistContainerView.transform = .identity
            }
            
        } completion: { [weak self] finished in
            guard let self = self, finished else { return }
            
            // Ensure segment control is in the correct final state
            self.segmentControl.setSelectedSegmentIndex(pageIndex, animated: false)
            
            // Hide the off-screen container to improve performance
            if pageIndex == 0 {
                self.watchlistContainerView.isHidden = true
                self.coinsContainerView.isHidden = false
                self.navigationItem.title = "Markets"
                
                // Show back to top button on coins tab (if user has scrolled)
                if self.collectionView.contentOffset.y > 200 {
                    self.showBackToTopButton()
                }
                
                // Seamless tab resource management
                self.startAutoRefresh()
                self.watchlistVC?.pausePeriodicUpdates()
            } else {
                self.coinsContainerView.isHidden = true
                self.watchlistContainerView.isHidden = false
                self.navigationItem.title = "Watchlist"
                
                // Hide back to top button on watchlist tab
                self.hideBackToTopButton()
                
                // Seamless tab resource management
                self.stopAutoRefresh()
                self.watchlistVC?.resumePeriodicUpdates()
                
                #if DEBUG
                // Show database contents when switching to watchlist
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let items = Dependencies.container.watchlistManager().watchlistItems
                    let tableData = items.map { 
                        ("\($0.symbol ?? "?") (\($0.name ?? "Unknown"))", "ID: \($0.id) | Rank: \($0.cmcRank)")
                    }
                    AppLogger.databaseTable("Watchlist Database Contents", items: tableData)
                }
                #endif
            }
            
            // Reset transforms for hidden containers
            if self.coinsContainerView.isHidden {
                self.coinsContainerView.transform = .identity
            }
            if self.watchlistContainerView.isHidden {
                self.watchlistContainerView.transform = .identity
            }
            
            self.isTransitioning = false
            
            AppLogger.ui("Page transition completed to: \(pageIndex == 0 ? "Markets" : "Watchlist")")
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
        AppLogger.ui("Pull-to-Refresh | User initiated refresh")
        
        // Prevent multiple concurrent refreshes
        guard !isRefreshing else {
            AppLogger.ui("Pull-to-Refresh | Already refreshing - cancelled")
            refreshControl.endRefreshing()
            return
        }
        
        isRefreshing = true
        AppLogger.ui("Pull-to-Refresh | Starting data fetch...")
        
        // Debug: Print sort state before refresh
        AppLogger.ui("Pull-to-refresh - Before fetch:")
        AppLogger.ui("  UI: \(sortHeaderView.currentSortColumn) \(sortHeaderView.currentSortOrder == .descending ? "DESC" : "ASC")")
        AppLogger.ui("  VM: \(viewModel.getCurrentSortColumn()) \(viewModel.getCurrentSortOrder() == .descending ? "DESC" : "ASC")")
        
        // Use SharedCoinDataManager for pull-to-refresh instead of individual ViewModel calls
        Dependencies.container.sharedCoinDataManager().forceUpdate()
        
        AppLogger.ui("Pull-to-Refresh | Data fetch completed")
        
        self.isRefreshing = false
        self.refreshControl.endRefreshing()
        
        // Sync SortHeaderView UI with ViewModel's current sort state
        self.syncSortHeaderWithViewModel()
        
        AppLogger.ui("Pull-to-Refresh | Spinner stopped, refresh complete")
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
                cell.coinImageView.downloadImage(fromURL: urlString)
            } else {
                // Only log missing logos for top coins (helps identify data issues)
                if coin.cmcRank <= 50 {
                    AppLogger.cache("Missing logo for top coin \(coin.name) (Rank: \(coin.cmcRank))", level: .warning)
                }
                cell.coinImageView.setPlaceholder()
            }
            
            return cell
        }
        
        collectionView.dataSource = dataSource
    }
    
    private func configureEmptyState() {
        // Configure empty state view with better messaging
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.text = "No Cryptocurrencies"
        configuration.secondaryText = "Unable to load cryptocurrency data.\nPlease check your connection and try again."
        configuration.image = UIImage(systemName: "chart.bar.xaxis")
        
        emptyStateView = UIContentUnavailableView(configuration: configuration)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        coinsContainerView.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: coinsContainerView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: coinsContainerView.centerYAnchor)
        ])
        
        // Hide empty state view initially
        emptyStateView.isHidden = true
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
                guard let self = self else { return }
                
                // Don't apply snapshot if skeleton loading is active
                guard !SkeletonLoadingManager.isShowingSkeleton(in: self.collectionView) else { return }
                
                // Show/hide empty state based on coin count
                let isEmpty = coins.isEmpty
                self.emptyStateView.isHidden = !isEmpty
                self.collectionView.isHidden = isEmpty
                
                // Only update collection view if not empty
                if !isEmpty {
                    var snapshot = NSDiffableDataSourceSnapshot<CoinSection, Coin>()
                    snapshot.appendSections([.main])
                    snapshot.appendItems(coins)
                    self.dataSource.apply(snapshot, animatingDifferences: true)
                }
            }
            .store(in: &cancellables) // Keeps this subscription alive
        
        // Bind logo updates (e.g fetched after coin data)
        viewModel.coinLogos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        // Bind error message to show alert with retry option
        viewModel.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showRetryAlert(title: "Error", message: error)
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
        
        // Bind loading state to show/hide skeleton screens in collection view
        Dependencies.container.sharedCoinDataManager().isFetchingFreshData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFetchingFresh in
                guard let self = self else { return }
                
                if isFetchingFresh {
                    // Show skeleton loading only when fetching fresh data from API
                    SkeletonLoadingManager.showSkeletonInCollectionView(self.collectionView, cellType: .coinCell, numberOfItems: 10)
                    // Hide empty state while skeleton is loading
                    self.emptyStateView.isHidden = true
                    self.collectionView.isHidden = false
                    AppLogger.ui("Loading | Showing skeleton screens - fetching fresh API data")
                } else {
                    // Hide skeleton loading from collection view
                    SkeletonLoadingManager.dismissSkeletonFromCollectionView(self.collectionView)
                    // Restore original data source
                    self.collectionView.dataSource = self.dataSource
                    
                    // Force refresh data source with current data after skeleton is dismissed
                    if !self.viewModel.currentCoins.isEmpty {
                        var snapshot = NSDiffableDataSourceSnapshot<CoinSection, Coin>()
                        snapshot.appendSections([.main])
                        snapshot.appendItems(self.viewModel.currentCoins)
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                        
                        // Show collection view, hide empty state
                        self.collectionView.isHidden = false
                        self.emptyStateView.isHidden = true
                    } else {
                        // Show empty state, hide collection view
                        self.collectionView.isHidden = true
                        self.emptyStateView.isHidden = false
                    }
                    AppLogger.ui("Loading | Hiding skeleton screens - using cached data or fetch complete")
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
    
    private func showRetryAlert(title: String, message: String) {
        // Enhanced alert dialog with retry functionality
        
        // 🚫 Prevent multiple alerts from showing simultaneously
        if presentedViewController is UIAlertController {
            return // Already showing an alert
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Add retry action
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.viewModel.retryFetchCoins {
                // Completion handler - could add success feedback here
            }
        })
        
        // Add dismiss action
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        
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
    // The timer runs independently every 30 seconds
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
    
    // MARK: - Legacy Child ViewController Timer Management
    // TODO: Update CoinDetailsVC to use proper navigation lifecycle instead
    
    func stopAutoRefreshFromChild() {
        // Legacy method - called by CoinDetailsVC to stop background auto-refresh
        let currentIndex = segmentControl?.selectedSegmentIndex ?? 0
        if currentIndex == 0 {
            stopAutoRefresh()
            AppLogger.performance("⏸️ CoinListVC: Stopped auto-refresh from child request")
        }
    }
    
    func resumeAutoRefreshFromChild() {
        // Legacy method - called by CoinDetailsVC when returning to resume auto-refresh
        let currentIndex = segmentControl?.selectedSegmentIndex ?? 0
        if currentIndex == 0 {
            startAutoRefresh()
            AppLogger.performance("🔄 CoinListVC: Resumed auto-refresh from child request")
        }
    }
    
    func stopWatchlistTimersFromChild() {
        // Legacy method - stop the embedded WatchlistVC timers
        let currentIndex = segmentControl?.selectedSegmentIndex ?? 0
        if currentIndex == 1 {
            watchlistVC?.pausePeriodicUpdates()
            AppLogger.performance("⏸️ CoinListVC: Stopped watchlist timers from child request")
        }
    }
    
    func resumeWatchlistTimersFromChild() {
        // Legacy method - resume the embedded WatchlistVC timers
        let currentIndex = segmentControl?.selectedSegmentIndex ?? 0
        if currentIndex == 1 {
            watchlistVC?.resumePeriodicUpdates()
            AppLogger.performance("🔄 CoinListVC: Resumed watchlist timers from child request")
        }
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
        AppLogger.performance("Auto-Refresh | Starting price update cycle...")
        viewModel.fetchPriceUpdatesForVisibleCoins(visibleCoinIds) { [weak self] in
            self?.isRefreshing = false
        }
    }

    
    // MARK: - Optimized Price Update Logic with Animations
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
            
            // Get old price for animation comparison
            let oldPrice = cell.priceLabel.text ?? coin.priceString
            let newPrice = coin.priceString
            
            // Update cell with animated price changes
            cell.updatePriceDataAnimated(withOldPrice: oldPrice,
                                                   newPrice: newPrice,
                                           percentChange24h: coin.percentChangeString(for: currentFilter),
                                              sparklineData: sparklineNumbers,
                                          isPositiveChange: coin.isPositiveChange(for: currentFilter),
                                                  animated: true)
            
            updatedCellsCount += 1
        }
        
        if updatedCellsCount > 0 {
            AppLogger.performance("UI Refresh | Updated \(updatedCellsCount) visible cells")
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
        animateToPage(index)
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
            AppLogger.ui("Synced sort header UI: \(viewModel.getCurrentSortColumn()) \(viewModel.getCurrentSortOrder() == .descending ? "DESC" : "ASC")")
        }
    }
    
    private func syncViewModelWithSortHeader() {
        // Ensure ViewModel starts with the same state as SortHeaderView
        let headerColumn = sortHeaderView.currentSortColumn
        let headerOrder = sortHeaderView.currentSortOrder
        
        if viewModel.getCurrentSortColumn() != headerColumn || viewModel.getCurrentSortOrder() != headerOrder {
            viewModel.updateSorting(column: headerColumn, order: headerOrder)
            AppLogger.ui("Synced ViewModel with SortHeader: \(headerColumn) \(headerOrder == .descending ? "DESC" : "ASC")")
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
        let watchlistManager = Dependencies.container.watchlistManager()
        
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
        
        // Handle back to top button visibility based on scroll position (only on coins tab)
        let offsetY = scrollView.contentOffset.y
        let currentIndex = segmentControl?.selectedSegmentIndex ?? 0
        
        // Only show/hide button on coins tab (index 0)
        if currentIndex == 0 {
            // Show button when scrolled down more than 200 points, hide when near top
            if offsetY > 200 {
                showBackToTopButton()
            } else if offsetY < 100 {
                hideBackToTopButton()
            }
        }
        
        // Load more coins when scrolling near the bottom
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
            AppLogger.performance("Scroll | Triggered pagination at \(String(format: "%.1f", scrollProgress * 100))%")
            viewModel.loadMoreCoins()
        }
    }
}

// MARK: - SortHeaderViewDelegate

extension CoinListVC: SortHeaderViewDelegate {
    func sortHeaderView(_ headerView: SortHeaderView, didSelect column: CryptoSortColumn, order: CryptoSortOrder) {
        AppLogger.ui("Sort: Column \(column) | Order: \(order == .descending ? "Descending" : "Ascending")")
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
        AppLogger.ui("Filter Selected: \(filter.displayName)")
        
        // Apply the filter - ViewModel will handle loading state and LoadingView will show automatically
        viewModel.updatePriceChangeFilter(filter)
        
        // Update header view state to reflect the new filter
        filterHeaderView.updateFilterState(viewModel.currentFilterState)
        updateSortHeaderForCurrentFilter() // Also update sort header
        updateAllVisibleCellsForFilterChange() // Update all visible cells for percentage change
    }
    
    func filterModalVC(_ modalVC: FilterModalVC, didSelectTopCoinsFilter filter: TopCoinsFilter) {
        AppLogger.ui("Filter Selected: \(filter.displayName)")
        
        // Apply the filter - ViewModel will handle loading state and LoadingView will show automatically
        viewModel.updateTopCoinsFilter(filter)
        
        // Update header view state to reflect the new filter
        filterHeaderView.updateFilterState(viewModel.currentFilterState)
        updateSortHeaderForCurrentFilter() // Also update sort header
        updateAllVisibleCellsForFilterChange() // Update all visible cells for percentage change
    }
    
    func filterModalVCDidCancel(_ modalVC: FilterModalVC) {
        // Handle cancellation if needed
        AppLogger.ui("Filter modal was cancelled")
    }
}

// MARK: - SegmentControlDelegate

extension CoinListVC: SegmentControlDelegate {
    func segmentControl(_ segmentControl: SegmentControl, didSelectSegmentAt index: Int) {
        let segmentName = index == 0 ? "Markets" : "Watchlist"
        AppLogger.ui("Segment switched to: \(segmentName)")
        
        // Prevent multiple transitions
        guard !isTransitioning else { return }
        
        animateToPage(index)
    }
}


    
    #if DEBUG
    private func showWatchlistDatabaseContents() {
        let items = Dependencies.container.watchlistManager().watchlistItems
        let tableData = items.map { item in
            ("\(item.symbol ?? "?") (\(item.name ?? "Unknown"))", "ID: \(item.id) | Rank: \(item.cmcRank)")
        }
        AppLogger.databaseTable("Watchlist Database Contents - \(items.count) items", items: tableData)
    }
    #endif

// MARK: - UIGestureRecognizerDelegate

extension CoinListVC {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow horizontal page swiping to work with vertical collection view scrolling
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
           let otherPanGesture = otherGestureRecognizer as? UIPanGestureRecognizer {
            
            let velocity = panGesture.velocity(in: view)
            
            // If the primary gesture is more horizontal than vertical, allow simultaneous recognition
            if abs(velocity.x) > abs(velocity.y) {
                return true
            }
        }
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow our page-switching pan gestures to begin if they're primarily horizontal
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
           gestureRecognizer.view == coinsContainerView || gestureRecognizer.view == watchlistContainerView {
            
            let velocity = panGesture.velocity(in: view)
            let translation = panGesture.translation(in: view)
            
            // Only begin if the gesture is primarily horizontal
            return abs(velocity.x) > abs(velocity.y) || abs(translation.x) > abs(translation.y)
        }
        return true
    }
}


