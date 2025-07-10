import UIKit
import Combine

final class CoinListVC: UIViewController {
    
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
    
    var autoRefreshTimer: Timer?                                            // Timer to refresh visible cells every few seconds
    let autoRefreshInterval: TimeInterval = 5                               // Interval in seconds
    
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
        viewModel.fetchCoins() // Fetch fresh data every time view appears
        startAutoRefresh()     // Start auto-refreshing price updates
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAutoRefresh() //  Stop Timer to avoid memory leaks / Unnecessary API Calls
    }
    
    
    // MARK: - UI Setup
    
    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Markets"
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
        view.addSubview(collectionView)
        
        // Pull to refresh
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Pull to Refresh

    @objc func handleRefresh() {
        viewModel.fetchCoins {
            self.refreshControl.endRefreshing()
        }
    }
    
    // MARK: - Diffable Data Source Setup
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<CoinSection, Coin>(collectionView: collectionView) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoinCell.reuseID(), for: indexPath) as? CoinCell else {
                return UICollectionViewCell()
            }
            
            let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }
            
            // Configure the cell with all relevant info
            cell.configure(
                withRank: coin.cmcRank,
                name: coin.name,
                price: coin.priceString,
                market: coin.marketSupplyString,
                percentChange24h: coin.percentChange24hString,
                sparklineData: sparklineNumbers,
                isPositiveChange: coin.isPositiveChange
            )
            
            // Load the coin logo image if available
            if let urlString = self?.viewModel.coinLogos[coin.id] {
                cell.coinImageView.downloadImage(fromURL: urlString)
            } else {
                cell.coinImageView.setPlaceholder()
            }
            
            return cell
        }
        
        collectionView.dataSource = dataSource
    }
    
    // MARK: - ViewModel Bindings with Combine

    // Combine handles threading
    // Combines listens for changes to ui updates such as coins. (since they are @Published)
    // even if data comes from the background thread, it sends it back on the main thread
    // handles async-queue switching
    // Combine uses GCD queues
    private func bindViewModel() {
        // Bind coin list changes
        viewModel.$coins
            .receive(on: DispatchQueue.main) // ensures UI updates happens on the main thread
            .sink { [weak self] coins in // Creates a combine subscription
                var snapshot = NSDiffableDataSourceSnapshot<CoinSection, Coin>()
                snapshot.appendSections([.main])
                snapshot.appendItems(coins)
                self?.dataSource.apply(snapshot, animatingDifferences: true)
            }
            .store(in: &cancellables) // Keeps this subscription alive
        
        // Bind logo updates (e.g fetched after coin data)
        viewModel.$coinLogos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        // Bind error message to show alert
        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(title: "Error", message: error)
            }
            .store(in: &cancellables)
        
    }
    
    private func showAlert(title: String, message: String) {
        // Reusable alert dialog for errors
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Auto-Refresh Logic
    
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
    
    private func refreshVisibleCells() {
        guard !viewModel.isLoading else { return }
        
        // Fetch the latest price updates and refresh only visible cells
        viewModel.fetchPriceUpdates { [weak self] in
            guard let self = self else { return }
            
            for indexPath in self.collectionView.indexPathsForVisibleItems {
                guard let coin = self.viewModel.coins[safe: indexPath.item],
                      let cell = self.collectionView.cellForItem(at: indexPath) as? CoinCell else { continue }
                
                let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }
                
                // Update cell without reloading the whole list
                cell.updatePriceData(
                    withPrice: coin.priceString,
                    percentChange24h: coin.percentChange24hString,
                    sparklineData: sparklineNumbers,
                    isPositiveChange: coin.isPositiveChange
                )
            }
        }
    }
}

// MARK: - Scroll Pagination

extension CoinListVC: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Navigate to coin details screen when user taps a coin
        let selectedCoin = viewModel.coins[indexPath.item]
        let detailsVC = CoinDetailsVC(coin: selectedCoin)
        navigationController?.pushViewController(detailsVC, animated: true)
        
        collectionView.deselectItem(at: indexPath, animated: true)
        
    }
    
    // This function is called every time the user scrolls the collection view.
    // Implement infinite scroll thresholding
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // Load more coins when scrolling near the bottom
        let offsetY = scrollView.contentOffset.y
        
        // The current vertical position the user has scrolled from the top.
        let contentHeight = scrollView.contentSize.height
        
        // The total height of the scrollable content (all coin cells combined).
        let height = scrollView.frame.size.height
        
        // Calculate how far the user has scrolled as a percentage
        // Calculate scroll progress as a ratio:
        // (current scroll position from top + visible height) / total scrollable content height
        // This gives a value between 0.0 (top) and 1.0 (bottom).
        let scrollProgress = (offsetY + height) / contentHeight
        
        // If user has scrolled past 70% of the total content height, trigger pagination.
        if scrollProgress > 0.7 {
            viewModel.loadMoreCoins()
        }
    }
}
