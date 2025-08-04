import UIKit
import Combine

final class WatchlistVC: UIViewController {
    
    // MARK: - Section Enum for Diffable Data Source
    
    enum WatchlistSection {
        case main
    }
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private let viewModel: WatchlistVM
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<WatchlistSection, Coin>!
    
    private let refreshControl = UIRefreshControl()
    private var emptyStateView: UIContentUnavailableView!
    private var filterHeaderView: FilterHeaderView!
    private var sortHeaderView: SortHeaderView!
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts WatchlistVM for better testability and modularity.
     * Uses dependency container for default instance.
     */
    init(viewModel: WatchlistVM = Dependencies.container.watchlistViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.viewModel = Dependencies.container.watchlistViewModel()
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureCollectionView()
        configureDataSource()
        bindViewModel()
        setupEmptyState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Resume periodic price updates when tab becomes active
        viewModel.startPeriodicUpdates()
        
        // Only refresh if data is empty (first time) - for seamless tab switching
        if viewModel.currentWatchlistCoins.isEmpty {
            viewModel.refreshWatchlist()
        }
        
        AppLogger.ui("Entering Watchlist Tab")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop periodic price updates when tab becomes inactive
        viewModel.stopPeriodicUpdates()
        
        // Cancel any in-flight API requests to save resources
        viewModel.cancelAllRequests()
        
        AppLogger.ui("Leaving Watchlist Tab")
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Container View Controller Lifecycle
    
    // These methods are called by the container view controller (CoinListVC)
    
    func preloadDataSilently() {
        // Preload data without showing loading state for seamless tab switching
        AppLogger.performance("WatchlistVC: Preloading data silently")
        viewModel.refreshWatchlistSilently()
    }
    
    func pausePeriodicUpdates() {
        // Pause periodic updates without calling full lifecycle (for seamless tab switching)
        viewModel.stopPeriodicUpdates()
        AppLogger.performance("WatchlistVC: Paused periodic updates for seamless tab switch")
    }
    
    func resumePeriodicUpdates() {
        // Resume periodic updates without calling full lifecycle (for seamless tab switching)
        viewModel.startPeriodicUpdates()
        AppLogger.performance("WatchlistVC: Resumed periodic updates for seamless tab switch")
    }
    
    func scrollToTop() {
        // Scroll to the top of the watchlist collection view
        guard !viewModel.currentWatchlistCoins.isEmpty else { return }
        collectionView.setContentOffset(.zero, animated: true)
    }
    
    // MARK: - UI Setup
    
    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Watchlist"
        
        // Add clear all button if needed
        setupNavigationItems()
        
        // Setup filter header (with just 24h% button)
        setupFilterHeaderView()
        
        // Setup sort header
        setupSortHeaderView()
    }
    
    private func setupNavigationItems() {
        let clearAllButton = UIBarButtonItem(
            title: "Clear All",
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )
        clearAllButton.tintColor = .systemRed
        navigationItem.rightBarButtonItem = clearAllButton
    }
    
    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "Clear Watchlist",
            message: "Are you sure you want to remove all coins from your watchlist?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            Dependencies.container.watchlistManager().clearWatchlist()
        })
        
        present(alert, animated: true)
    }
    
    private func setupFilterHeaderView() {
        filterHeaderView = FilterHeaderView(watchlistMode: true)  // Enable watchlist mode
        filterHeaderView.delegate = self
        filterHeaderView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterHeaderView)
        
        NSLayoutConstraint.activate([
            filterHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            filterHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Update filter header with current state
        updateFilterHeaderForCurrentState()
    }
    
    private func setupSortHeaderView() {
        sortHeaderView = SortHeaderView()
        sortHeaderView.delegate = self
        sortHeaderView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sortHeaderView)
        
        NSLayoutConstraint.activate([
            sortHeaderView.topAnchor.constraint(equalTo: filterHeaderView.bottomAnchor),
            sortHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sortHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Set default sort to rank descending (best ranks first)
        sortHeaderView.currentSortColumn = .rank
        sortHeaderView.currentSortOrder = .descending
        sortHeaderView.updateSortIndicators()
        
        // Update sort header for current filter state
        updateSortHeaderForCurrentFilter()
        
        // Sync ViewModel with SortHeader
        syncViewModelWithSortHeader()
    }
    
    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.bounds.width, height: 80)
        layout.minimumLineSpacing = 0
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        
        // Register cell
        collectionView.register(CoinCell.self, forCellWithReuseIdentifier: CoinCell.reuseID())
        
        // Pull to refresh
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: sortHeaderView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func handleRefresh() {
        viewModel.refreshWatchlist()
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<WatchlistSection, Coin>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CoinCell.reuseID(),
                for: indexPath
            ) as? CoinCell else {
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
    
    private func bindViewModel() {
        // Bind watchlist coins
        viewModel.watchlistCoins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coins in
                self?.updateDataSource(coins)
                self?.updateEmptyState(isEmpty: coins.isEmpty)
                self?.updateNavigationItems(hasCoins: !coins.isEmpty)
            }
            .store(in: &cancellables)
        
        // Bind logo updates
        viewModel.coinLogos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Reload visible cells to update logos
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        // Bind loading state
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                if isLoading {
                    if self.refreshControl.isRefreshing == false {
                        // Show skeleton loading in the collection view
                        SkeletonLoadingManager.showSkeletonInCollectionView(self.collectionView, cellType: .coinCell, numberOfItems: 8)
                    }
                } else {
                    // Hide skeleton loading and restore data source
                    SkeletonLoadingManager.dismissSkeletonFromCollectionView(self.collectionView)
                    self.collectionView.dataSource = self.dataSource
                    
                    // Force update data source with current data after skeleton is dismissed
                    if !self.viewModel.currentWatchlistCoins.isEmpty {
                        self.updateDataSource(self.viewModel.currentWatchlistCoins)
                    }
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &cancellables)
        
        // Bind error messages
        viewModel.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(title: "Error", message: error)
            }
            .store(in: &cancellables)
        
        // Bind price updates
        viewModel.updatedCoinIds
            .receive(on: DispatchQueue.main)
            .filter { !$0.isEmpty }
            .sink { [weak self] updatedCoinIds in
                self?.updateCellsForChangedCoins(updatedCoinIds)
            }
            .store(in: &cancellables)
    }
    
    private func updateDataSource(_ coins: [Coin]) {
        // Don't apply snapshot if skeleton loading is active
        guard !SkeletonLoadingManager.isShowingSkeleton(in: collectionView) else { return }
        
        // Filter out invalid coins and remove duplicates to prevent crashes
        let validCoins = coins
            .filter { $0.id > 0 && !$0.name.isEmpty && !$0.symbol.isEmpty } // Remove invalid coins
            .uniqued(by: { $0.id }) // Remove duplicates by ID
        
        var snapshot = NSDiffableDataSourceSnapshot<WatchlistSection, Coin>()
        snapshot.appendSections([.main])
        snapshot.appendItems(validCoins)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func updateCellsForChangedCoins(_ updatedCoinIds: Set<Int>) {
        guard !updatedCoinIds.isEmpty else { return }
        
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let coin = viewModel.currentWatchlistCoins[safe: indexPath.item],
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
        }
        
        viewModel.clearUpdatedCoinIds()
    }
    
    // MARK: - Filter Update Methods
    
    private func updateAllVisibleCellsForFilterChange() {
        // Update all visible cells when filter changes to show new percentage values
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let coin = viewModel.currentWatchlistCoins[safe: indexPath.item],
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
    
    private func updateNavigationItems(hasCoins: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = hasCoins
    }
    
    // MARK: - Empty State
    
    private func setupEmptyState() {
        // Configure empty state view with better messaging - matching CoinListVC style
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.text = "No Watchlist Items"
        configuration.secondaryText = "Add coins to your watchlist by tapping the +\nbutton above or by long pressing on any coin in\nthe Markets tab"
        configuration.image = UIImage(systemName: "star.fill")
        
        emptyStateView = UIContentUnavailableView(configuration: configuration)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)
        view.bringSubviewToFront(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Hide empty state view initially
        emptyStateView.isHidden = true
    }
    
    private func updateEmptyState(isEmpty: Bool) {
        // Simple visibility toggle - empty state is already added to view in setupEmptyState
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        
        // Ensure empty state appears above all other views when shown
        if isEmpty {
            view.bringSubviewToFront(emptyStateView)
        }
    }
    
    // MARK: - Filter Helper Methods
    
    private func updateFilterHeaderForCurrentState() {
        filterHeaderView.updateFilterState(viewModel.currentFilterState)
    }
    
    private func updateSortHeaderForCurrentFilter() {
        let priceChangeTitle = viewModel.currentFilterState.priceChangeFilter.shortDisplayName + "%"
        sortHeaderView.updatePriceChangeColumnTitle(priceChangeTitle)
    }
    
    // MARK: - Sort Header Sync Methods
    
    private func syncViewModelWithSortHeader() {
        // Ensure ViewModel starts with the same state as SortHeaderView
        let headerColumn = sortHeaderView.currentSortColumn
        let headerOrder = sortHeaderView.currentSortOrder
        
        if viewModel.getCurrentSortColumn() != headerColumn || viewModel.getCurrentSortOrder() != headerOrder {
            viewModel.updateSorting(column: headerColumn, order: headerOrder)
            AppLogger.ui("Synced ViewModel with SortHeader: \(headerColumn) \(headerOrder == .descending ? "DESC" : "ASC")")
        }
    }
    
    // MARK: - Utility Methods
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension WatchlistVC: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let selectedCoin = viewModel.currentWatchlistCoins[indexPath.item]
        let detailsVC = CoinDetailsVC(coin: selectedCoin)
        navigationController?.pushViewController(detailsVC, animated: true)
    }
    
    // MARK: - Swipe to Remove
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let coin = viewModel.currentWatchlistCoins[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let removeAction = UIAction(
                title: "Remove from Watchlist",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.remove(coin, at: indexPath)
            }
            
            let detailsAction = UIAction(
                title: "View Details",
                image: UIImage(systemName: "info.circle")
            ) { [weak self] _ in
                let detailsVC = CoinDetailsVC(coin: coin)
                self?.navigationController?.pushViewController(detailsVC, animated: true)
            }
            
            return UIMenu(title: coin.name, children: [removeAction, detailsAction])
        }
    }
    
    private func remove(_ coin: Coin, at indexPath: IndexPath, animated: Bool = true) {
        // Show confirmation alert for removal
        let alert = UIAlertController(
            title: "Remove from Watchlist",
            message: "Are you sure you want to remove \(coin.symbol) from your watchlist?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            // Remove from Core Data
            self?.viewModel.removeFromWatchlist(coin)
            
            // Show feedback
            self?.showRemovalFeedback(coinSymbol: coin.symbol)
        })
        
        present(alert, animated: true)
    }
    
    private func showRemovalFeedback(coinSymbol: String) {
        // Create a toast-like feedback view
        let feedbackView = UIView()
        feedbackView.backgroundColor = .systemRed
        feedbackView.layer.cornerRadius = 8
        feedbackView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: "trash.fill"))
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Removed \(coinSymbol) from watchlist"
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
}

// MARK: - SortHeaderViewDelegate

extension WatchlistVC: SortHeaderViewDelegate {
    func sortHeaderView(_ headerView: SortHeaderView, didSelect column: CryptoSortColumn, order: CryptoSortOrder) {
        AppLogger.ui("Watchlist sort: Column \(column) | Order: \(order == .descending ? "Descending" : "Ascending")")
        viewModel.updateSorting(column: column, order: order)
    }
}

// MARK: - FilterHeaderViewDelegate

extension WatchlistVC: FilterHeaderViewDelegate {
    func filterHeaderView(_ headerView: FilterHeaderView, didTapPriceChangeButton button: FilterButton) {
        let modalVC = FilterModalVC(filterType: .priceChange, currentState: viewModel.currentFilterState)
        modalVC.delegate = self
        present(modalVC, animated: true)
    }
    
    func filterHeaderView(_ headerView: FilterHeaderView, didTapTopCoinsButton button: FilterButton) {
        // Not used in watchlist mode
    }
    
    func filterHeaderView(_ headerView: FilterHeaderView, didTapAddCoinsButton button: UIButton) {
        // Present the AddCoinsVC modally
        let addCoinsVC = AddCoinsVC()
        let navigationController = UINavigationController(rootViewController: addCoinsVC)
        navigationController.modalPresentationStyle = .pageSheet
        
        // Configure the sheet presentation
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.preferredCornerRadius = 16
            sheet.prefersGrabberVisible = true
        }
        
        present(navigationController, animated: true) { [weak self] in
            // Set up a completion handler for when the modal is dismissed
            navigationController.presentationController?.delegate = self
        }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension WatchlistVC: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Refresh watchlist when AddCoinsVC is dismissed
        AppLogger.ui("AddCoinsVC dismissed - refreshing watchlist")
        
        // Force refresh the watchlist to pick up newly added coins
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.viewModel.refreshWatchlist()
        }
    }
}

// MARK: - FilterModalVCDelegate

extension WatchlistVC: FilterModalVCDelegate {
    func filterModalVC(_ modalVC: FilterModalVC, didSelectPriceChangeFilter filter: PriceChangeFilter) {
        AppLogger.ui("Watchlist Filter Selected: \(filter.displayName)")
        
        // Apply the filter - ViewModel will handle loading state
        viewModel.updatePriceChangeFilter(filter)
        
        // Update header views to reflect the new filter
        filterHeaderView.updateFilterState(viewModel.currentFilterState)
        updateSortHeaderForCurrentFilter()
        updateAllVisibleCellsForFilterChange() // Update all visible cells for the new filter
    }
    
    func filterModalVC(_ modalVC: FilterModalVC, didSelectTopCoinsFilter filter: TopCoinsFilter) {
        // Not used in watchlist mode
    }
    
    func filterModalVCDidCancel(_ modalVC: FilterModalVC) {
        AppLogger.ui("Filter modal was cancelled")
    }
}

// MARK: - Collection View Layout

extension WatchlistVC: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 80)
    }
} 
