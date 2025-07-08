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
        case "365d": days = "365"
        default:    days = "7"
        }
        
        let cacheKey = "\(slug)-\(days)"
        
        // Debug logging
        print("🎯 VM: User selected \(range) → Converting to \(days) days")
        print("🔑 Cache key: \(cacheKey)")
        
        if let cached = chartCache[cacheKey] {
            print("📦 Using cached data: \(cached.count) points")
            self.chartPoints = cached
            return
        }
        
        print("🌐 Making API call for \(slug) with \(days) days")
        
        coinManager.fetchChartData(for: slug, range: days)
            .retry(1)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Chart fetch failed: \(error)")
                }
            }, receiveValue: { [weak self] prices in
                print("✅ Received \(prices.count) data points for \(range)")
                print("📊 Price range: \(prices.min() ?? 0) - \(prices.max() ?? 0)")
                
                self?.chartCache[cacheKey] = prices
                self?.chartPoints = prices
            })
            .store(in: &cancellables)
    }
    
}

