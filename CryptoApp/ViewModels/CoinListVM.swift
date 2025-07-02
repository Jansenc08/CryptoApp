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
    
    func fetchCoins(convert: String = "USD") {
        // Reset pagination for fresh fetch
        currentPage = 1
        canLoadMore = true
        coins = []
        
        isLoading = true
        errorMessage = nil

        coinManager.getTopCoins(limit: itemsPerPage, convert: convert)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.canLoadMore = false
                }
            } receiveValue: { [weak self] coins in
                self?.coins = coins
                self?.canLoadMore = coins.count == self?.itemsPerPage
                let ids = coins.map { $0.id }
                self?.fetchCoinLogos(forIDs: ids)
            }
            .store(in: &cancellables)
    }
    
    func loadMoreCoins(convert: String = "USD") {
        guard canLoadMore && !isLoadingMore && !isLoading else { return }
        
        currentPage += 1
        isLoadingMore = true
        errorMessage = nil
        
        // Calculate the starting point for the next page
        let start = (currentPage - 1) * itemsPerPage + 1
        
        coinManager.getTopCoins(limit: itemsPerPage, convert: convert, start: start)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingMore = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.currentPage -= 1 // Reset page on error
                }
            } receiveValue: { [weak self] newCoins in
                guard let self = self else { return }
                
                // Append new coins to existing ones
                self.coins.append(contentsOf: newCoins)
                self.canLoadMore = newCoins.count == self.itemsPerPage
                
                // Fetch logos for new coins
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
}
