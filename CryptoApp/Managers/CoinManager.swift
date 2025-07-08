//
//  CoinManager.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//
//

import Foundation
import Combine

final class CoinManager {
    
    private let coinService: CoinService
    
    init(coinService: CoinService = CoinService()) {
        self.coinService = coinService
    }

    func getTopCoins(limit: Int = 100, convert: String = "USD", start: Int = 1) -> AnyPublisher<[Coin], NetworkError> {
        return coinService.fetchTopCoins(limit: limit, convert: convert, start: start)
            .map { coins in
                // Do any data transformation here
                return coins
            }
            .eraseToAnyPublisher()
    }
    
    func getCoinLogos(forIDs ids: [Int]) -> AnyPublisher<[Int: String], Never> {
        return coinService.fetchCoinLogos(forIDs: ids)
    }
    
    func getQuotes(for ids: [Int], convert: String = "USD") -> AnyPublisher<[Int: Quote], NetworkError> {
        return coinService.fetchQuotes(for: ids, convert: convert)
    }
    
    // FIXED: Now properly handles all range cases including 365 days
    func fetchChartData(for coinSlug: String, range: String, currency: String = "usd") -> AnyPublisher<[Double], NetworkError> {
        // Map your range string to CoinGecko's 'days' parameter
        let daysParam: String
        switch range {
        case "1":     // 24h from VM
            daysParam = "1"
        case "7":     // 7d from VM
            daysParam = "7"
        case "30":    // 30d from VM
            daysParam = "30"
        case "365":   // 1 year from VM
            daysParam = "365"
        default:
            print("⚠️ Unrecognized range: \(range), defaulting to 1 day")
            daysParam = "1"
        }
        
        print("🔍 CoinManager: Fetching chart data for \(coinSlug) with \(daysParam) days")

        return coinService.fetchCoinGeckoChartData(for: coinSlug, currency: currency, days: daysParam)
    }
}
