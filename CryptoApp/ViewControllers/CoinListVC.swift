import UIKit
import Combine

final class CoinListVC: UIViewController {

    enum CoinSection {
        case main
    }

    var collectionView: UICollectionView!
    let viewModel = CoinListVM()
    var cancellables = Set<AnyCancellable>()
    var dataSource: UICollectionViewDiffableDataSource<CoinSection, Coin>!

    let imageCache = NSCache<NSString, UIImage>()
    let refreshControl = UIRefreshControl()

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
        viewModel.fetchCoins() // Always fetch fresh data
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Track screen view (e.g. analytics)
        print("CoinListVC appeared")
    }

    // MARK: - Setup

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

    @objc func handleRefresh() {
        viewModel.fetchCoins {
            self.refreshControl.endRefreshing()
        }
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<CoinSection, Coin>(collectionView: collectionView) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoinCell.reuseID(), for: indexPath) as? CoinCell else {
                return UICollectionViewCell()
            }

            let sparklineNumbers = coin.sparklineData.map { NSNumber(value: $0) }

            cell.configure(
                withRank: coin.cmcRank,
                name: coin.name,
                price: coin.priceString,
                market: coin.marketSupplyString,
                percentChange24h: coin.percentChange24hString,
                sparklineData: sparklineNumbers,
                isPositiveChange: coin.isPositiveChange
            )

            if let urlString = self?.viewModel.coinLogos[coin.id] {
                cell.coinImageView.downloadImage(fromURL: urlString)
            } else {
                cell.coinImageView.setPlaceholder()
            }

            return cell
        }

        collectionView.dataSource = dataSource
    }

    // Combine handles threading
    // Combines listens for changes to ui updates such as coins. (since they are @Published)
    // even if data comes from the background thread, it sends it back on the main thread
    // handles async-queue switching
    // Combine uses GCD queues 
    private func bindViewModel() {
        viewModel.$coins
            .receive(on: DispatchQueue.main) // ensures UI updates happens on the main thread
            .sink { [weak self] coins in // Creates a combine subscription
                var snapshot = NSDiffableDataSourceSnapshot<CoinSection, Coin>()
                snapshot.appendSections([.main])
                snapshot.appendItems(coins)
                self?.dataSource.apply(snapshot, animatingDifferences: true)
            }
            .store(in: &cancellables) // Keeps this subscription alive

        viewModel.$coinLogos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(title: "Error", message: error)
            }
            .store(in: &cancellables)

    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Scroll Pagination

extension CoinListVC: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height

        if offsetY > contentHeight - height * 1.2 {
            viewModel.loadMoreCoins()
        }
    }
}

// MARK: - Preview

#Preview {
    CoinListVC()
}
