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

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureCollectionView()
        configureDataSource()

        bindViewModel()
        viewModel.fetchCoins() // fetch default (USD)
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Markets"
    }

    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.bounds.width, height: 80)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.register(CoinCell.self, forCellWithReuseIdentifier: CoinCell.reuseID())

        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<CoinSection, Coin>(collectionView: collectionView) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoinCell.reuseID(), for: indexPath) as? CoinCell else {
                return UICollectionViewCell()
            }

            cell.configure(withRank: coin.cmcRank, name: coin.name, symbol: coin.symbol, price: coin.priceString)

            if let urlString = self?.viewModel.coinLogos[coin.id], let url = URL(string: urlString) {
                self?.loadImage(from: url, into: cell.coinImageView)
            } else {
                cell.coinImageView.setPlaceholder()
            }

            return cell
        }
        
        collectionView.dataSource = dataSource
    }


    private func bindViewModel() {
        viewModel.$coins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coins in
                var snapshot = NSDiffableDataSourceSnapshot<CoinSection, Coin>()
                snapshot.appendSections([.main])
                snapshot.appendItems(coins)
                self?.dataSource.apply(snapshot, animatingDifferences: true)
            }

            .store(in: &cancellables)

        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.presentAlert(title: "Error", message: error)
            }
            .store(in: &cancellables)
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alert, animated: true)
    }
    
    private func loadImage(from url: URL, into imageView: UIImageView) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                }
            }
        }.resume()
    }
}
