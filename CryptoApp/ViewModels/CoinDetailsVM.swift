//
//  CoinDetailsVM.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

// Handles, Fetching & Caching Chart Data.
// Expose stats and chart data points to CoinDetailsVC
// Manage Loading state
// Supports scroll to load more data
// Formats values for display

import Foundation
import Combine

final class CoinDetailsVM: ObservableObject {
    
    // @Published variables are obeserved by the view
    // Any change to them triggers UI updates via combine
    @Published var chartPoints: [Double] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    var shouldReloadChart = true
    
    private let coin: Coin // holds current coin to hold data
    private let coinManager: CoinManager // holds current manager to hold data
    
    var cancellables = Set<AnyCancellable>() //  stores combine subscriptions
    
    private var chartCache: [String: ChartDataCache] = [:]
    private let maxCacheAge: TimeInterval = 300
    
    private var currentRange: String = "24h"
    private var isLoadingMoreData = false // prevents duplicate calls when scrolling left
    
    // Dynamically creates a list of stats based on available data
    // Returns Data such as Market cap, volime, fdv etc.
    // uses helper class: formattedWithAbbreviations() to convert values to 1.23B, 999K etc
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
    
    // Checks if Data is already cached and fresh
    // if yes -> use it directly
    // if no -> make an API request via coinManager
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
    
    // Calls API via coinManager.fetchChartData.
    // Stores the data in cache.
    // Publishes the data into chartPoints.
    func fetchChartDataFromAPI(slug: String, days: String, cacheKey: String) {
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
    
    // Used when the chart scrolls to the left (past data).
    // Avoids reloading if already loading.
    // Uses an extended time range to get more data and prepends it.
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
    
    //Takes older historical points and prepends them to chartPoints.
    // Keeps existing points intact.
    // Disables chart redraw by setting shouldReloadChart = false.
    func appendHistoricalData(_ newData: [Double]) {
        let olderData = newData.prefix(max(0, newData.count - chartPoints.count))
        shouldReloadChart = false // Disables UI Reload
        chartPoints = Array(olderData) + chartPoints
        print("📈 Appended \(olderData.count) historical points. Total: \(chartPoints.count)")
    }
    
    // Converts (24h -> 1, 7d - > 7 ) to pass to API
    func mapRangeToDays(_ range: String) -> String {
        switch range {
        case "24h": return "1"
        case "7d": return "7"
        case "30d": return "30"
        case "365d": return "365"
        default: return "7"
        }
    }
    
    // This function is used when user scrolls to the edge of the chart to fetch older historical data than are currently displayed
    // eg: if 24h is selected -> Loads 7 days more
    // eg: if 7d ius selected -> Loads 20 days more
    // Used in loadMoreHistoricalDat(for:beforedate)
    func calculateExtendedRange(for range: String) -> String {
        switch range {
        case "24h": return "7"
        case "7d": return "30"
        case "30d": return "90"
        case "365d": return "max"
        default: return "30"
        }
    }
    
    
    func cleanExpiredCache() {
        let now = Date()
        chartCache = chartCache.filter { now.timeIntervalSince($0.value.timestamp) < maxCacheAge }
    }
    
    var canLoadMoreData: Bool {
        return !isLoadingMoreData && !chartPoints.isEmpty
    }
}








