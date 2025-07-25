//
//  AddCoinsVC.swift
//  CryptoApp
//
//  Created by AI Assistant on 7/8/25.
//

import UIKit
import Combine
import Foundation

final class AddCoinsVC: UIViewController {
    
    // MARK: - Section Enum for Diffable Data Source
    
    enum AddCoinsSection {
        case main
    }
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private var searchBarComponent: SearchBarComponent!
    private var addButton: UIButton!
    
    private let viewModel = CoinListVM() // Reuse existing view model for coin data
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<AddCoinsSection, Coin>!
    
    // Selection management
    private var selectedCoinIds: Set<Int> = []
    private var allCoins: [Coin] = []
    private var filteredCoins: [Coin] = []
    
    // Search debouncing
    private var searchWorkItem: DispatchWorkItem?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureSearchBar()
        configureCollectionView()
        configureAddButton()
        configureDataSource()
        bindViewModel()
        
        // Load many more coins for better selection
        loadMoreCoinsForSelection()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchBarComponent.resignFirstResponder()
    }
    
    // MARK: - UI Setup
    
    private func configureView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Add Coins"
        
        // Add close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
    }
    
    private func configureSearchBar() {
        searchBarComponent = SearchBarComponent(placeholder: "Search coins to add...")
        searchBarComponent.delegate = self
        searchBarComponent.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure for inline search usage
        searchBarComponent.configureForInlineSearch()
        
        view.addSubview(searchBarComponent)
        
        NSLayoutConstraint.activate([
            searchBarComponent.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBarComponent.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBarComponent.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBarComponent.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.bounds.width - 32, height: 70)
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 100, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.allowsMultipleSelection = true
        collectionView.keyboardDismissMode = .onDrag
        
        // Register cells
        collectionView.register(AddCoinCell.self, forCellWithReuseIdentifier: AddCoinCell.reuseID())
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: searchBarComponent.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func configureAddButton() {
        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.backgroundColor = .systemBlue
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        addButton.layer.cornerRadius = 25
        addButton.isEnabled = false
        addButton.alpha = 0.5
        
        updateAddButtonTitle()
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        view.addSubview(addButton)
        
        NSLayoutConstraint.activate([
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<AddCoinsSection, Coin>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, coin in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AddCoinCell.reuseID(),
                for: indexPath
            ) as? AddCoinCell else {
                return UICollectionViewCell()
            }
            
            let isSelected = self?.selectedCoinIds.contains(coin.id) ?? false
            let logoURL = self?.viewModel.currentCoinLogos[coin.id]
            
            cell.configure(
                withSymbol: coin.symbol,
                name: coin.name,
                logoURL: logoURL,
                isSelected: isSelected
            )
            
            return cell
        }
        
        collectionView.dataSource = dataSource
    }
    
    private func bindViewModel() {
        // Bind coin list changes
        viewModel.coins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coins in
                self?.allCoins = coins
                self?.updateFilteredCoins()
            }
            .store(in: &cancellables)
        
        // Bind logo updates
        viewModel.coinLogos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
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
                self?.showAlert(title: "Error", message: error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Management
    
    private func updateFilteredCoins() {
        let searchText = searchBarComponent.text?.lowercased() ?? ""
        
        if searchText.isEmpty {
            filteredCoins = allCoins
        } else {
            filteredCoins = allCoins.filter { coin in
                coin.name.lowercased().contains(searchText) ||
                coin.symbol.lowercased().contains(searchText)
            }
        }
        
        updateDataSource()
    }
    
    private func updateDataSource() {
        // Filter out coins already in watchlist
        let watchlistManager = WatchlistManager.shared
        let availableCoins = filteredCoins.filter { !watchlistManager.isInWatchlist(coinId: $0.id) }
        
        var snapshot = NSDiffableDataSourceSnapshot<AddCoinsSection, Coin>()
        snapshot.appendSections([.main])
        snapshot.appendItems(availableCoins)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func updateAddButtonTitle() {
        let count = selectedCoinIds.count
        if count == 0 {
            addButton.setTitle("Select coins to add", for: .normal)
            addButton.isEnabled = false
            addButton.alpha = 0.5
        } else {
            addButton.setTitle("Add \(count) coin\(count == 1 ? "" : "s") to Watchlist", for: .normal)
            addButton.isEnabled = true
            addButton.alpha = 1.0
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func addButtonTapped() {
        guard !selectedCoinIds.isEmpty else { return }
        
        let watchlistManager = WatchlistManager.shared
        var addedCount = 0
        
        for coinId in selectedCoinIds {
            if let coin = allCoins.first(where: { $0.id == coinId }) {
                let logoURL = viewModel.currentCoinLogos[coin.id]
                watchlistManager.addToWatchlist(coin, logoURL: logoURL)
                addedCount += 1
            }
        }
        
        // Show success feedback
        let message = "Added \(addedCount) coin\(addedCount == 1 ? "" : "s") to your watchlist"
        showSuccessFeedback(message: message)
        
        // Manually post notification to ensure watchlist refreshes immediately
        NotificationCenter.default.post(name: .watchlistDidUpdate, object: nil, userInfo: ["action": "batch_add"])
        
        // Clear selection and update UI
        selectedCoinIds.removeAll()
        updateAddButtonTitle()
        collectionView.reloadData()
        updateDataSource() // Remove newly added coins from list
        
        // Dismiss after a longer delay to give WatchlistVC time to refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.dismiss(animated: true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showSuccessFeedback(message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        // Auto-dismiss after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadMoreCoinsForSelection() {
        // Set a higher limit for top coins to give users more options
        viewModel.updateTopCoinsFilter(.top500) // Load top 500 coins instead of default 100
        viewModel.fetchCoins()
        
        // Also trigger pagination to load even more coins
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadAdditionalCoins()
        }
    }
    
    private func loadAdditionalCoins() {
        // Load more pages to get even more coin options
        for _ in 0..<5 { // Load 5 more pages (100 more coins)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.viewModel.loadMoreCoins()
            }
        }
    }
}

// MARK: - SearchBarComponentDelegate

extension AddCoinsVC: SearchBarComponentDelegate {
    
    func searchBarComponent(_ searchBar: SearchBarComponent, textDidChange searchText: String) {
        // Cancel previous search work item
        searchWorkItem?.cancel()
        
        // Create new work item with debouncing
        searchWorkItem = DispatchWorkItem { [weak self] in
            self?.updateFilteredCoins()
        }
        
        // Execute after 0.3 seconds delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: searchWorkItem!)
    }
    
    func searchBarComponentDidBeginEditing(_ searchBar: SearchBarComponent) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarComponentCancelButtonClicked(_ searchBar: SearchBarComponent) {
        searchBar.text = ""
        updateFilteredCoins()
    }
}

// MARK: - UICollectionViewDelegate

extension AddCoinsVC: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let coin = dataSource.itemIdentifier(for: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) as? AddCoinCell else { return }
        
        let isCurrentlySelected = selectedCoinIds.contains(coin.id)
        
        if isCurrentlySelected {
            selectedCoinIds.remove(coin.id)
        } else {
            selectedCoinIds.insert(coin.id)
        }
        
        cell.setSelectedForWatchlist(!isCurrentlySelected, animated: true)
        updateAddButtonTitle()
        
        // Animate button change
        UIView.animate(withDuration: 0.2) {
            self.addButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.addButton.transform = .identity
            }
        }
    }
    
    // MARK: - Infinite Scroll
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        // Load more coins when scrolling near the bottom (75% through content)
        if contentHeight > 0 {
            let scrollProgress = (offsetY + height) / contentHeight
            if scrollProgress > 0.75 {
                // Trigger loading more coins from the view model
                viewModel.loadMoreCoins()
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension AddCoinsVC: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width - 32, height: 70)
    }
} 