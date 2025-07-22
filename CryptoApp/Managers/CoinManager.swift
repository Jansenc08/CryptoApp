//
//  CoinManager.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//
//

import Foundation
import Combine

final class CoinManager: CoinManagerProtocol {
    
    private let coinService: CoinServiceProtocol
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts CoinServiceProtocol for:
     * - Easy mocking in unit tests
     * - Swappable service implementations
     * - Better testability and modularity
     * 
     * Falls back to default CoinService for backward compatibility
     */
    init(coinService: CoinServiceProtocol = CoinService()) {
        self.coinService = coinService
    }

    // Added priority parameters to all methods so the ViewModels can specify urgency
    func getTopCoins(limit: Int = 100, convert: String = "USD", start: Int = 1, sortType: String = "market_cap", sortDir: String = "desc", priority: RequestPriority = .normal) -> AnyPublisher<[Coin], NetworkError> {
        // Simple pass-through to CoinService with priority
        return coinService.fetchTopCoins(limit: limit, convert: convert, start: start, sortType: sortType, sortDir: sortDir, priority: priority)
            .map { coins in
                // Do any data transformation here if needed
                return coins
            }
            .eraseToAnyPublisher()
    }
    
    // Logo fetching defaults to low priority since they're visual enhancements, not critical data
    func getCoinLogos(forIDs ids: [Int], priority: RequestPriority = .low) -> AnyPublisher<[Int: String], Never> {
        return coinService.fetchCoinLogos(forIDs: ids, priority: priority)
    }
    
    // Price quotes is set to normal priority - important but not as urgent as user filter changes
    func getQuotes(for ids: [Int], convert: String = "USD", priority: RequestPriority = .normal) -> AnyPublisher<[Int: Quote], NetworkError> {
        return coinService.fetchQuotes(for: ids, convert: convert, priority: priority)
    }
    
    // Chart data fetching supports priority - high priority for user filter changes
    func fetchChartData(for geckoID: String, range: String, currency: String = "usd", priority: RequestPriority = .normal) -> AnyPublisher<[Double], NetworkError> {
        // Map range string to CoinGecko's 'days' parameter
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
        
        // Enhanced logging to show priority level - helps debug filter performance
        print("🔍 CoinManager: Fetching chart data for CoinGecko ID \(geckoID) with \(daysParam) days (priority: \(priority.description))")

        // Pass the priority all the way down to CoinService - this shows how filter changes get high priority
        return coinService.fetchCoinGeckoChartData(for: geckoID, currency: currency, days: daysParam, priority: priority)
    }
    
            // Fetch real OHLC candlestick data from CoinGecko
    func fetchOHLCData(for geckoID: String, range: String, currency: String = "usd", priority: RequestPriority = .normal) -> AnyPublisher<[OHLCData], NetworkError> {
        // Map range string to CoinGecko's 'days' parameter
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
            print("⚠️ Unrecognized OHLC range: \(range), defaulting to 1 day")
            daysParam = "1"
        }
        
        print("🔍 CoinManager: Fetching real OHLC data for CoinGecko ID \(geckoID) with \(daysParam) days (priority: \(priority.description))")
        
        return coinService.fetchCoinGeckoOHLCData(for: geckoID, currency: currency, days: daysParam, priority: priority)
    }
}
