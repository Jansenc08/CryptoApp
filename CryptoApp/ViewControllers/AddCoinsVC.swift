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
    
    // MARK: - Constants for AddCoinSelectionType
    
    private let selectionTypeAdd = AddCoinSelectionType(rawValue: 0)!
    private let selectionTypeRemove = AddCoinSelectionType(rawValue: 1)!
    
    // MARK: - Section Enum for Diffable Data Source
    
    enum AddCoinsSection: CaseIterable {
        case watchlisted
        case available
        
        var title: String {
            switch self {
            case .watchlisted:
                return "Currently in Watchlist"
            case .available:
                return "Available Coins"
            }
        }
    }
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private var searchBarComponent: SearchBarComponent!
    private var addButton: UIButton!
    
    private let viewModel: CoinListVM // Reuse existing view model for coin data
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<AddCoinsSection, Coin>!
    
    // Selection management - now tracks both additions and removals
    private var selectedCoinIds: Set<Int> = []
    private var coinsToRemove: Set<Int> = [] // Track watchlisted coins selected for removal
    private var allCoins: [Coin] = []
    private var filteredCoins: [Coin] = []
    private var watchlistedCoins: [Coin] = [] // Coins currently in watchlist
    
    // Search debouncing
    private var searchWorkItem: DispatchWorkItem?
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Uses dependency container for ViewModel creation.
     * Provides better testability and modularity.
     */
    init(viewModel: CoinListVM = Dependencies.container.coinListViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.viewModel = Dependencies.container.coinListViewModel()
        super.init(coder: coder)
    }
    
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
        
        // Ensure ALL watchlisted coins have their logos loaded
        loadWatchlistLogos()
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
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 100, right: 16)
        layout.headerReferenceSize = CGSize(width: view.bounds.width, height: 40)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.allowsMultipleSelection = true
        collectionView.keyboardDismissMode = .onDrag
        
        // Register cells and headers
        collectionView.register(AddCoinCell.self, forCellWithReuseIdentifier: AddCoinCell.reuseID())
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeader")
        
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
            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AddCoinCell.reuseID(),
                for: indexPath
            ) as? AddCoinCell else {
                return UICollectionViewCell()
            }
            
            let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            
            // Get logo URL: works for ALL coins (DOGE, ULTIMA, YFI, etc.)
            let logoURL: String?
            if section == .watchlisted {
                // For ANY watchlisted coin, get logo from stored watchlist data
                let watchlistManager = Dependencies.container.watchlistManager()
                logoURL = watchlistManager.watchlistItems.first { $0.coinId == coin.id }?.logoURL
                    ?? self.viewModel.currentCoinLogos[coin.id] // fallback to current logos
            } else {
                // For available coins, use current logos from view model
                logoURL = self.viewModel.currentCoinLogos[coin.id]
            }
            
            // Determine selection state and type based on section and user selections
            let isSelected: Bool
            let selectionType: AddCoinSelectionType
            
            switch section {
            case .watchlisted:
                // For watchlisted coins, show as selected if they're marked for removal
                isSelected = self.coinsToRemove.contains(coin.id)
                selectionType = self.selectionTypeRemove
            case .available:
                // For available coins, show as selected if they're marked for addition
                isSelected = self.selectedCoinIds.contains(coin.id)
                selectionType = self.selectionTypeAdd
            }
            
            cell.configure(
                withSymbol: coin.symbol,
                name: coin.name,
                logoURL: logoURL,
                isSelected: isSelected,
                selectionType: selectionType
            )
            
            return cell
        }
        
        // Configure supplementary view provider for section headers
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else {
                return nil
            }
            
            let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "SectionHeader",
                for: indexPath
            )
            
            // Configure header view
            headerView.subviews.forEach { $0.removeFromSuperview() }
            
            let titleLabel = UILabel()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            titleLabel.textColor = .label
            
            let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            titleLabel.text = section?.title
            
            headerView.addSubview(titleLabel)
            
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
                titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
            ])
            
            return headerView
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
                guard let self = self else { return }
                
                if isLoading {
                    // Show skeleton loading for AddCoinCell type
                    SkeletonLoadingManager.showSkeletonInCollectionView(self.collectionView, cellType: .addCoinCell, numberOfItems: 12)
                } else {
                    // Hide skeleton loading and restore data source
                    SkeletonLoadingManager.dismissSkeletonFromCollectionView(self.collectionView)
                    self.collectionView.dataSource = self.dataSource
                    
                    // Force update data source with current data after skeleton is dismissed
                    self.updateDataSource()
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
        // Don't apply snapshot if skeleton loading is active
        guard !SkeletonLoadingManager.isShowingSkeleton(in: collectionView) else { return }
        
        let watchlistManager = Dependencies.container.watchlistManager()
        
        // Get ALL watchlisted coins directly (DOGE, ULTIMA, YFI, etc. - not just from API response)
        let allWatchlistedCoins = watchlistManager.getWatchlistCoins()
        
        // Apply search filter to watchlisted coins
        let searchText = searchBarComponent.text?.lowercased() ?? ""
        let currentWatchlistedCoins = searchText.isEmpty 
            ? allWatchlistedCoins
            : allWatchlistedCoins.filter { coin in
                coin.name.lowercased().contains(searchText) ||
                coin.symbol.lowercased().contains(searchText)
            }
        
        // Get available coins (not in watchlist)
        let availableCoins = filteredCoins.filter { !watchlistManager.isInWatchlist(coinId: $0.id) }
        
        // Update local watchlisted coins array
        watchlistedCoins = currentWatchlistedCoins
        
        var snapshot = NSDiffableDataSourceSnapshot<AddCoinsSection, Coin>()
        
        // Add watchlisted section if there are any watchlisted coins
        if !currentWatchlistedCoins.isEmpty {
            snapshot.appendSections([.watchlisted])
            snapshot.appendItems(currentWatchlistedCoins)
        }
        
        // Add available section if there are any available coins
        if !availableCoins.isEmpty {
            snapshot.appendSections([.available])
            snapshot.appendItems(availableCoins)
        }
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func updateAddButtonTitle() {
        let addCount = selectedCoinIds.count
        let removeCount = coinsToRemove.count
        let totalChanges = addCount + removeCount
        
        if totalChanges == 0 {
            addButton.setTitle("Select coins to modify watchlist", for: .normal)
            addButton.isEnabled = false
            addButton.alpha = 0.5
        } else {
            var titleComponents: [String] = []
            
            if addCount > 0 {
                titleComponents.append("Add \(addCount)")
            }
            
            if removeCount > 0 {
                titleComponents.append("Remove \(removeCount)")
            }
            
            let actionText = titleComponents.joined(separator: " • ")
            addButton.setTitle("\(actionText) coin\(totalChanges == 1 ? "" : "s")", for: .normal)
            addButton.isEnabled = true
            addButton.alpha = 1.0
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func addButtonTapped() {
        guard !selectedCoinIds.isEmpty || !coinsToRemove.isEmpty else { return }
        
        let watchlistManager = Dependencies.container.watchlistManager()
        var addedCount = 0
        var removedCount = 0
        
        // Handle additions
        for coinId in selectedCoinIds {
            if let coin = allCoins.first(where: { $0.id == coinId }) {
                let logoURL = viewModel.currentCoinLogos[coin.id]
                watchlistManager.addToWatchlist(coin, logoURL: logoURL)
                addedCount += 1
            }
        }
        
        // Handle removals
        for coinId in coinsToRemove {
            watchlistManager.removeFromWatchlist(coinId: coinId)
            removedCount += 1
        }
        
        // Show success feedback
        var messageComponents: [String] = []
        if addedCount > 0 {
            messageComponents.append("Added \(addedCount) coin\(addedCount == 1 ? "" : "s")")
        }
        if removedCount > 0 {
            messageComponents.append("Removed \(removedCount) coin\(removedCount == 1 ? "" : "s")")
        }
        let message = messageComponents.joined(separator: " and ") + " from your watchlist"
        showSuccessFeedback(message: message)
        
        // Manually post notification to ensure watchlist refreshes immediately
        let actionType = addedCount > 0 && removedCount > 0 ? "batch_modify" : (addedCount > 0 ? "batch_add" : "batch_remove")
        NotificationCenter.default.post(name: .watchlistDidUpdate, object: nil, userInfo: ["action": actionType])
        
        // Clear selections and update UI
        selectedCoinIds.removeAll()
        coinsToRemove.removeAll()
        updateAddButtonTitle()
        collectionView.reloadData()
        updateDataSource() // Refresh the entire list
        
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
    
    private func loadWatchlistLogos() {
        let watchlistManager = Dependencies.container.watchlistManager()
        let watchlistedCoins = watchlistManager.getWatchlistCoins()
        
        // Get ALL coin IDs from watchlist (DOGE, ULTIMA, YFI, etc.)
        let coinIds = watchlistedCoins.map { $0.id }
        
        if !coinIds.isEmpty {
            // Fetch logos for ALL watchlisted coins
            viewModel.fetchCoinLogos(forIDs: coinIds)
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
        
        // Execute after 0.3 seconds delay -> Debouncing 
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
        
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        
        switch section {
        case .watchlisted:
            // Handle watchlisted coin selection (for removal)
            let isCurrentlySelectedForRemoval = coinsToRemove.contains(coin.id)
            
            if isCurrentlySelectedForRemoval {
                coinsToRemove.remove(coin.id)
            } else {
                coinsToRemove.insert(coin.id)
            }
            
            cell.setSelectedForWatchlist(!isCurrentlySelectedForRemoval, selectionType: selectionTypeRemove, animated: true)
            
        case .available:
            // Handle available coin selection (for addition)
            let isCurrentlySelectedForAddition = selectedCoinIds.contains(coin.id)
            
            if isCurrentlySelectedForAddition {
                selectedCoinIds.remove(coin.id)
            } else {
                selectedCoinIds.insert(coin.id)
            }
            
            cell.setSelectedForWatchlist(!isCurrentlySelectedForAddition, selectionType: selectionTypeAdd, animated: true)
        }
        
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
