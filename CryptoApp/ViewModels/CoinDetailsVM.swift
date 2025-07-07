//
//  CoinDetailsVM.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import Foundation
import Combine

final class CoinDetailsVM: ObservableObject {
    @Published var chartPoints: [Double] = []

    private let coin: Coin
    private let coinManager: CoinManager
    var cancellables = Set<AnyCancellable>()

    private var chartCache: [String: [Double]] = [:]

    init(coin: Coin, coinManager: CoinManager = CoinManager()) {
        self.coin = coin
        self.coinManager = coinManager
    }

    func fetchChartData(for range: String) {
        guard let slug = coin.slug?.lowercased() else { return }

        let days: String
        switch range {
        case "24h": days = "1"
        case "7d":  days = "7"
        case "30d": days = "30"
        case "All": days = "365" // CoinGecko free tier limit
        default:    days = "7"    // Fallback
        }

        let cacheKey = "\(slug)-\(days)"
        if let cached = chartCache[cacheKey] {
            self.chartPoints = cached
            return
        }

        coinManager.fetchChartData(for: slug, range: days)
            .retry(1)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Chart fetch failed: \(error)")
                }
            }, receiveValue: { [weak self] prices in
                self?.chartCache[cacheKey] = prices
                self?.chartPoints = prices
            })
            .store(in: &cancellables)
    }

}

