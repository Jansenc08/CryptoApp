//
//  CoinListVM.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import Foundation
import Combine

final class CoinListVM: ObservableObject {

    // MARK: - Published Properties (Observed by the UI)

    @Published var coins: [Coin] = []                      // All coins displayed in the collection view
    @Published var coinLogos: [Int: String] = [:]          // Coin ID to logo URL mapping
    @Published var isLoading: Bool = false                 // True during initial data load
    @Published var isLoadingMore: Bool = false             // True during pagination
    @Published var errorMessage: String?                   // Displayable error message (binds to alerts)

    // MARK: - Dependencies

    private let coinManager: CoinManager                   // Handles all API calls
    private var cancellables = Set<AnyCancellable>()       // Stores Combine subscriptions

    // MARK: - Pagination Properties

    private let itemsPerPage = 20                          // Number of coins to load per API request
    private var currentPage = 1                            // Current page number (used to calculate API offset)
    private var canLoadMore = true                         // Flag that indicates if more data can be fetched

    // MARK: - Init

    init(coinManager: CoinManager = CoinManager()) {
        self.coinManager = coinManager
    }

    // MARK: - Initial Data Fetch

    func fetchCoins(convert: String = "USD", onFinish: (() -> Void)? = nil) {
        // Reset state for a fresh fetch
        currentPage = 1
        canLoadMore = true
        coins = []
        isLoading = true
        errorMessage = nil

        // Call API to fetch top coins (page 1)
        coinManager.getTopCoins(limit: itemsPerPage, convert: convert)
            .receive(on: DispatchQueue.main) // Ensure results update UI on main thread
            .sink { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.canLoadMore = false // Prevent retry if error occurred
                }
                onFinish?()
            } receiveValue: { [weak self] coins in
                self?.coins = coins

                // Only allow loading more if we got a full page, and we haven't hit the 100 coin cap
                self?.canLoadMore = coins.count == self?.itemsPerPage && coins.count < 100

                // Start fetching logos for the coins
                let ids = coins.map { $0.id }
                self?.fetchCoinLogos(forIDs: ids)
            }
            .store(in: &cancellables)
    }

    // MARK: - Pagination (Triggered on Scroll)

    func loadMoreCoins(convert: String = "USD") {
        
        // Request guarding
        // Prevent multiple calls from running concurrently
        // Ignores triggers while request is still in flight
        // Prevent duplicate loads or loading past the max cap
        // Only load more if we are not already loading more coins & we are not already doing a full refresh / fetch 
        guard canLoadMore && !isLoadingMore && !isLoading else { return }

        // Do not load more than 100 coins
        if coins.count >= 100 {
            canLoadMore = false
            return
        }

        // Advance to next page and start loading
        currentPage += 1
        isLoadingMore = true
        errorMessage = nil

        // Calculate start index for API pagination
        let start = (currentPage - 1) * itemsPerPage + 1

        coinManager.getTopCoins(limit: itemsPerPage, convert: convert, start: start)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingMore = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.currentPage -= 1 // Roll back page counter on failure
                }
            } receiveValue: { [weak self] newCoins in
                guard let self = self else { return }

                self.coins.append(contentsOf: newCoins)

                // If fewer than 20 returned or 100 reached, stop loading more
                if self.coins.count >= 100 || newCoins.count < self.itemsPerPage {
                    self.canLoadMore = false
                }

                // Fetch logos for newly appended coins
                let newIds = newCoins.map { $0.id }
                self.fetchCoinLogos(forIDs: newIds)
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Coin Logos (Called after loading coins)

    func fetchCoinLogos(forIDs ids: [Int]) {
        coinManager.getCoinLogos(forIDs: ids)
            .sink { [weak self] logos in
                // Merge new logos with existing ones (new overrides old if needed)
                self?.coinLogos.merge(logos) { _, new in new }
            }
            .store(in: &cancellables)
    }

    // MARK: - Periodic Price Update (Used by auto-refresh)

    func fetchPriceUpdates(completion: @escaping () -> Void) {
        let ids = coins.map { $0.id } // Get all coin IDs currently shown

        coinManager.getQuotes(for: ids)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    self?.errorMessage = error.localizedDescription
                }
                completion()
            } receiveValue: { [weak self] updatedQuotes in
                guard let self = self else { return }

                // Update price-related data in each coin
                for i in 0..<self.coins.count {
                    let id = self.coins[i].id
                    if let updated = updatedQuotes[id] {
                        self.coins[i].quote?["USD"] = updated
                    }
                }
                completion()
            }
            .store(in: &cancellables)
    }
}
