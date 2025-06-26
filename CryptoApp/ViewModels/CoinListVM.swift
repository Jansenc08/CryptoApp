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

                // 🧪 Debug: Check cmcRank for each coin
                for coin in coins {
                    print("🧪 \(coin.name) rank: \(coin.cmcRank)")
                }
            }
            .store(in: &cancellables)
    }
}
