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
    @Published var errorMessage: String?

    private let coinManager: CoinManager
    private var cancellables = Set<AnyCancellable>()
    
    init(coinManager: CoinManager = CoinManager()) {
        self.coinManager = coinManager
    }
    
    func fetchCoins(convert: String = "USD") {
        isLoading = true
        errorMessage = nil

        coinManager.getTopCoins(convert: convert)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] coins in
                self?.coins = coins
                let ids = coins.map { $0.id }
                self?.fetchCoinLogos(forIDs: ids)
            }
            .store(in: &cancellables)
    }

    private func fetchCoinLogos(forIDs ids: [Int]) {
        coinManager.getCoinLogos(forIDs: ids)
            .sink { [weak self] logos in
                self?.coinLogos = logos
            }
            .store(in: &cancellables)
    }
}

