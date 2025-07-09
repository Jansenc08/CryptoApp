//
//  CoinDetailsVM.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import Foundation
import Combine

struct StatItem {
    let title: String
    let value: String
}

extension Double {
    func formattedWithAbbreviations() -> String {
        let num = abs(self)
        let sign = self < 0 ? "-" : ""

        switch num {
        case 1_000_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000_000))B"
        case 1_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000))M"
        case 1_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000))K"
        default:
            return "\(sign)\(String(format: "%.2f", self))"
        }
    }
}

final class CoinDetailsVM: ObservableObject {
    @Published var chartPoints: [Double] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    var shouldReloadChart = true

    private let coin: Coin
    private let coinManager: CoinManager
    var cancellables = Set<AnyCancellable>()

    private var chartCache: [String: ChartDataCache] = [:]
    private let maxCacheAge: TimeInterval = 300

    private var currentRange: String = "24h"
    private var isLoadingMoreData = false
    
    var currentStats: [StatItem] {
        var items: [StatItem] = []

        if let quote = coin.quote?["USD"] {
            if let marketCap = quote.marketCap {
                items.append(StatItem(title: "Market Cap", value: marketCap.formattedWithAbbreviations()))
            }
            if let volume24h = quote.volume24h {
                items.append(StatItem(title: "Volume (24h)", value: volume24h.formattedWithAbbreviations()))
            }
            if let fdv = quote.fullyDilutedMarketCap {
                items.append(StatItem(title: "Fully Diluted Market Cap", value: fdv.formattedWithAbbreviations()))
            }
        }

        if let circulating = coin.circulatingSupply {
            items.append(StatItem(title: "Circulating Supply", value: circulating.formattedWithAbbreviations()))
        }

        if let total = coin.totalSupply {
            items.append(StatItem(title: "Total Supply", value: total.formattedWithAbbreviations()))
        }

        if let max = coin.maxSupply {
            items.append(StatItem(title: "Max Supply", value: max.formattedWithAbbreviations()))
        }

        items.append(StatItem(title: "Rank", value: "#\(coin.cmcRank)"))

        return items
    }


    init(coin: Coin, coinManager: CoinManager = CoinManager()) {
        self.coin = coin
        self.coinManager = coinManager
    }

    func fetchChartData(for range: String) {
        guard let slug = coin.slug?.lowercased() else { return }

        currentRange = range
        let days = mapRangeToDays(range)
        let cacheKey = "\(slug)-\(days)"

        if let cachedData = chartCache[cacheKey], !cachedData.isExpired() {
            print("📦 Using cached data: \(cachedData.data.count) points")
            self.chartPoints = cachedData.data
            return
        }

        fetchChartDataFromAPI(slug: slug, days: days, cacheKey: cacheKey)
    }

    private func fetchChartDataFromAPI(slug: String, days: String, cacheKey: String) {
        isLoading = true
        errorMessage = nil

        print("🌐 Making API call for \(slug) with \(days) days")

        coinManager.fetchChartData(for: slug, range: days)
            .retry(2)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Failed to load chart data: \(error.localizedDescription)"
                        print("❌ Chart fetch failed: \(error)")
                    }
                },
                receiveValue: { [weak self] prices in
                    guard let self = self else { return }
                    print("✅ Received \(prices.count) data points")
                    self.chartCache[cacheKey] = ChartDataCache(data: prices)
                    self.shouldReloadChart = true
                    self.chartPoints = prices
                    self.cleanExpiredCache()
                }
            )
            .store(in: &cancellables)
    }

    func loadMoreHistoricalData(for range: String, beforeDate: Date) {
        guard !isLoadingMoreData, let slug = coin.slug?.lowercased() else { return }

        isLoadingMoreData = true
        
        let extendedDays = calculateExtendedRange(for: range)
        let cacheKey = "\(slug)-extended-\(extendedDays)"

        if let cachedData = chartCache[cacheKey], !cachedData.isExpired() {
            print("📦 Using cached extended data: \(cachedData.data.count) points")
            appendHistoricalData(cachedData.data)
            isLoadingMoreData = false
            return
        }

        print("🌐 Loading more historical data for \(slug)")

        coinManager.fetchChartData(for: slug, range: extendedDays)
            .retry(1)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMoreData = false
                    if case .failure(let error) = completion {
                        print("❌ Extended data fetch failed: \(error)")
                    }
                },
                receiveValue: { [weak self] prices in
                    guard let self = self else { return }
                    print("✅ Received \(prices.count) extended data points")
                    self.chartCache[cacheKey] = ChartDataCache(data: prices)
                    self.appendHistoricalData(prices)
                }
            )
            .store(in: &cancellables)
    }

    private func appendHistoricalData(_ newData: [Double]) {
        let olderData = newData.prefix(max(0, newData.count - chartPoints.count))
        shouldReloadChart = false // Disables UI Reload
        chartPoints = Array(olderData) + chartPoints
        print("📈 Appended \(olderData.count) historical points. Total: \(chartPoints.count)")
    }

    private func mapRangeToDays(_ range: String) -> String {
        switch range {
        case "24h": return "1"
        case "7d": return "7"
        case "30d": return "30"
        case "365d": return "365"
        default: return "7"
        }
    }

    private func calculateExtendedRange(for range: String) -> String {
        switch range {
        case "24h": return "7"
        case "7d": return "30"
        case "30d": return "90"
        case "365d": return "max"
        default: return "30"
        }
    }

    private func cleanExpiredCache() {
        let now = Date()
        chartCache = chartCache.filter { now.timeIntervalSince($0.value.timestamp) < maxCacheAge }
    }

    var canLoadMoreData: Bool {
        return !isLoadingMoreData && !chartPoints.isEmpty
    }
}

private struct ChartDataCache {
    let data: [Double]
    let timestamp: Date

    init(data: [Double]) {
        self.data = data
        self.timestamp = Date()
    }

    func isExpired() -> Bool {
        return Date().timeIntervalSince(timestamp) > 300
    }
}
