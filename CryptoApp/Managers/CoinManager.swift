//
//  CoinManager.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
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
    
    // --- MODIFIED: fetchChartData now uses CoinGecko ---
        // The `slug` from CoinMarketCap's Coin object is generally compatible with CoinGecko's coin ID.
        func fetchChartData(for coinSlug: String, range: String, currency: String = "usd") -> AnyPublisher<[Double], NetworkError> {
            // Map your range string (e.g., "1h", "24h", "7d") to CoinGecko's 'days' parameter.
            let daysParam: String
            switch range {
            case "1h":
                // CoinGecko's 1-hour data is typically covered by '1' day, as it provides hourly data.
                // For truly 1-hour data points, you'd need a more granular API or client-side filtering.
                // For simplicity, we'll request 1 day and let the UI handle presentation.
                daysParam = "1"
            case "24h":
                daysParam = "1"
            case "7d":
                daysParam = "7"
            case "30d":
                daysParam = "30"
            default:
                daysParam = "1" // Default to 1 day if unrecognized
            }

            return coinService.fetchCoinGeckoChartData(for: coinSlug, currency: currency, days: daysParam)
        }
}
