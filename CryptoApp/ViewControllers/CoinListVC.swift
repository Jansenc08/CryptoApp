import UIKit
import Combine

final class CoinListVC: UIViewController {
    
    private var collectionView: UICollectionView!
    

    private let viewModel = CoinListVM()
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureCollectionView()
        bindViewModel()
        viewModel.fetchCoins()  // Default to USD
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
        collectionView.register(CoinCell.self, forCellWithReuseIdentifier: CoinCell.reuseID)
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        collectionView.dataSource = self
    }


    private func bindViewModel() {
        viewModel.$coins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
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
}


extension CoinListVC: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.coins.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoinCell.reuseID, for: indexPath) as? CoinCell else {
            return UICollectionViewCell()
        }
        let coin = viewModel.coins[indexPath.item]
        cell.configure(with: coin)
        return cell
    }
}
