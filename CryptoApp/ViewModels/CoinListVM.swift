//
//  CoinListVM.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import Foundation
import Combine

final class CoinListVM: ObservableObject {
    
    @Published var coins: [Coin] = []
    @Published var coinLogos: [Int: String] = [:]
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    private let coinManager: CoinManager
    private var cancellables = Set<AnyCancellable>()
    
    // Pagination properties
    private let itemsPerPage = 20
    private var currentPage = 1
    private var canLoadMore = true
    
    init(coinManager: CoinManager = CoinManager()) {
        self.coinManager = coinManager
    }
    
    func fetchCoins(convert: String = "USD", onFinish: (() -> Void)? = nil) {
        // Reset pagination for fresh fetch
        currentPage = 1
        canLoadMore = true
        coins = []
        
        isLoading = true
        errorMessage = nil

        coinManager.getTopCoins(limit: itemsPerPage, convert: convert)
        // Handles threading transition. After doing all the work, the result is sent back to the main thread for UI Updates
        // .sink is a way for COmbine to subscribe to results
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.canLoadMore = false
                }
                onFinish?()
            } receiveValue: { [weak self] coins in
                self?.coins = coins
                self?.canLoadMore = coins.count == self?.itemsPerPage && coins.count < 100
                let ids = coins.map { $0.id }
                self?.fetchCoinLogos(forIDs: ids)
            }
            .store(in: &cancellables)
    }
    
    func loadMoreCoins(convert: String = "USD") {
        guard canLoadMore && !isLoadingMore && !isLoading else { return }

        //Stop if already loaded 100 coins
        if coins.count >= 100 {
            canLoadMore = false
            return
        }

        currentPage += 1
        isLoadingMore = true
        errorMessage = nil

        let start = (currentPage - 1) * itemsPerPage + 1

        coinManager.getTopCoins(limit: itemsPerPage, convert: convert, start: start)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingMore = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.currentPage -= 1
                }
            } receiveValue: { [weak self] newCoins in
                guard let self = self else { return }

                self.coins.append(contentsOf: newCoins)

                // ✅ Cap total to 100 coins max
                if self.coins.count >= 100 || newCoins.count < self.itemsPerPage {
                    self.canLoadMore = false
                }

                let newIds = newCoins.map { $0.id }
                self.fetchCoinLogos(forIDs: newIds)
            }
            .store(in: &cancellables)
    }


    private func fetchCoinLogos(forIDs ids: [Int]) {
        coinManager.getCoinLogos(forIDs: ids)
            .sink { [weak self] logos in
                // Merge new logos with existing ones
                self?.coinLogos.merge(logos) { _, new in new }
            }
            .store(in: &cancellables)
    }
    
    func fetchPriceUpdates(completion: @escaping () -> Void) {
        let ids = coins.map { $0.id }

        coinManager.getQuotes(for: ids)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    self?.errorMessage = error.localizedDescription
                }
                completion()
            } receiveValue: { [weak self] updatedQuotes in
                guard let self = self else { return }

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
