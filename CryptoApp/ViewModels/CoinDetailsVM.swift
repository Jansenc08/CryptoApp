//  CoinDetailsVM.swift
//  CryptoApp

/**
 * CoinDetailsVM - Fixed Combine Best Practices
 *
 * FIXES:
 * - Fixed critical retain cycles in request handlers
 * - Proper subscription storage with cancellables
 * - Fixed memory leaks with timers
 * - Better threading with Combine operators
 * - Proper cleanup and cancellation
 */

import Foundation
import Combine

// MARK: - Price Change Indicator

struct PriceChangeIndicator {
    let direction: PriceDirection
    let amount: Double
    let percentage: Double
    
    enum PriceDirection {
        case up
        case down
        case neutral
    }
}

final class CoinDetailsVM: ObservableObject {

    // MARK: - Private Subjects (Internal State Management)
    
    private let chartPointsSubject = CurrentValueSubject<[Double], Never>([])
    private let ohlcDataSubject = CurrentValueSubject<[OHLCData], Never>([])
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = CurrentValueSubject<String?, Never>(nil)
    private let selectedStatsRangeSubject = CurrentValueSubject<String, Never>("24h")
    private let coinDataSubject: CurrentValueSubject<Coin, Never>
    private let priceChangeSubject = CurrentValueSubject<PriceChangeIndicator?, Never>(nil)

    // MARK: - Published AnyPublisher Properties (Reactive UI Binding)
    
    var chartPoints: AnyPublisher<[Double], Never> {
        chartPointsSubject.eraseToAnyPublisher()
    }
    
    var ohlcData: AnyPublisher<[OHLCData], Never> {
        ohlcDataSubject.eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    
    var errorMessage: AnyPublisher<String?, Never> {
        errorMessageSubject.eraseToAnyPublisher()
    }
    
    var selectedStatsRange: AnyPublisher<String, Never> {
        selectedStatsRangeSubject.eraseToAnyPublisher()
    }
    
    var coinData: AnyPublisher<Coin, Never> {
        coinDataSubject.eraseToAnyPublisher()
    }
    
    var priceChange: AnyPublisher<PriceChangeIndicator?, Never> {
        priceChangeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Current Value Accessors (For Internal Logic)
    
    var currentChartPoints: [Double] {
        chartPointsSubject.value
    }
    
    var currentOHLCData: [OHLCData] {
        ohlcDataSubject.value
    }
    
    var currentIsLoading: Bool {
        isLoadingSubject.value
    }
    
    var currentSelectedStatsRange: String {
        selectedStatsRangeSubject.value
    }
    
    var currentCoin: Coin {
        coinDataSubject.value
    }

    // MARK: - Core Dependencies
    
    private let coin: Coin
    private let coinManager: CoinManagerProtocol
    private let sharedCoinDataManager: SharedCoinDataManagerProtocol
    private let requestManager: RequestManagerProtocol
    var geckoID: String? // FIXED: Made public for cache checking
    
    // Chart configuration
    private var isSmoothingEnabled: Bool = true // Toggle for chart smoothing
    private var smoothingType: ChartSmoothingHelper.SmoothingType = .adaptive // Current smoothing algorithm
    
    // MARK: - FIXED: Proper Combine Subscription Management
    private var cancellables = Set<AnyCancellable>()
    private var chartDataCancellable: AnyCancellable? // FIXED: Dedicated cancellable for chart data
    private var ohlcDataCancellable: AnyCancellable? // FIXED: Dedicated cancellable for OHLC data
    
    // MARK: - State Management
    
    private var currentRange: String = "24h"
    private var currentChartType: ChartType = .line

    // MARK: - Computed Properties
    
    var currentStats: [StatItem] {
        return getStats(for: currentSelectedStatsRange)
    }
    
    // MARK: - Initialization
    
    init(coin: Coin, coinManager: CoinManagerProtocol, sharedCoinDataManager: SharedCoinDataManagerProtocol, requestManager: RequestManagerProtocol) {
        self.coin = coin
        self.coinManager = coinManager
        self.sharedCoinDataManager = sharedCoinDataManager
        self.requestManager = requestManager
        self.coinDataSubject = CurrentValueSubject<Coin, Never>(coin)

        // ID MAPPING: Convert CMC slug to CoinGecko ID for chart API
        if let slug = coin.slug, !slug.isEmpty {
            self.geckoID = slug.lowercased()
            print("✅ Using coin slug for \(coin.symbol): \(slug)")
        } else {
            print("❌ No slug found for \(coin.symbol) - chart data will not be available")
            self.geckoID = nil
        }
        
        // 🌐 SUBSCRIBE TO SHARED DATA: Get real-time price updates
        setupSharedCoinDataListener()
    }
    
    // MARK: - Shared Data Management
    
    /**
     * SHARED COIN DATA LISTENER
     * 
     * Subscribes to SharedCoinDataManager for real-time price updates
     * and triggers price change animations when prices change
     */
    private func setupSharedCoinDataListener() {
        sharedCoinDataManager.allCoins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allCoins in
                guard let self = self else { return }
                
                // Find updated data for this specific coin
                if let freshCoin = allCoins.first(where: { $0.id == self.coin.id }) {
                    self.handleFreshCoinData(freshCoin)
                }
            }
            .store(in: &cancellables)
    }
    
    /**
     * Handle fresh coin data from SharedCoinDataManager
     */
    private func handleFreshCoinData(_ freshCoin: Coin) {
        let currentCoin = coinDataSubject.value
        
        // Detect price changes
        if let oldPrice = currentCoin.quote?["USD"]?.price,
           let newPrice = freshCoin.quote?["USD"]?.price,
           abs(oldPrice - newPrice) > 0.001 {
            
            // Calculate price change
            let priceChange = newPrice - oldPrice
            let percentageChange = (priceChange / oldPrice) * 100
            
            let direction: PriceChangeIndicator.PriceDirection
            if priceChange > 0 {
                direction = .up
            } else if priceChange < 0 {
                direction = .down
            } else {
                direction = .neutral
            }
            
            let indicator = PriceChangeIndicator(
                direction: direction,
                amount: abs(priceChange),
                percentage: abs(percentageChange)
            )
            
            // Trigger price change animation
            priceChangeSubject.send(indicator)
            
            print("💰 CoinDetails: \(freshCoin.symbol) price changed: $\(String(format: "%.2f", oldPrice)) → $\(String(format: "%.2f", newPrice)) (\(direction))")
            print("💰 CoinDetails: Change amount: \(priceChange >= 0 ? "+" : "")$\(String(format: "%.2f", priceChange)), percentage: \(percentageChange >= 0 ? "+" : "")\(String(format: "%.2f", percentageChange))%")
            
            // Clear indicator after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.priceChangeSubject.send(nil)
            }
        }
        
        // Update coin data
        coinDataSubject.send(freshCoin)
    }

    // MARK: - Chart Type Management (Fixed Combine)
    
    func setChartType(_ chartType: ChartType, for range: String? = nil) {
        currentChartType = chartType
        let targetRange = range ?? currentRange
        
        if chartType == .candlestick {
            // FIXED: Check cache first and use immediately if available
            if let geckoID = geckoID,
               let cachedOHLCData = CacheService.shared.getOHLCData(for: geckoID, currency: "usd", days: mapRangeToDays(targetRange)),
               !cachedOHLCData.isEmpty {
                ohlcDataSubject.send(cachedOHLCData)
                errorMessageSubject.send(nil)
                print("📦 ✅ Using cached OHLC data: \(cachedOHLCData.count) candles for \(targetRange)")
                return
            }
            
            // Only show loading if we really need to fetch
            let cooldownStatus = requestManager.getCooldownStatus()
            if cooldownStatus.isInCooldown {
                let remainingTime = cooldownStatus.remainingSeconds
                errorMessageSubject.send("API cooldown active (\(remainingTime)s). Candlestick data temporarily unavailable.")
                return
            }
            
            // Only fetch if we don't have cached data
            fetchOHLCDataCombine(for: targetRange)
        } else {
            // FIXED: Cancel any pending OHLC requests when switching to line chart
            ohlcDataCancellable?.cancel()
            ohlcDataCancellable = nil
            
            // Only clear OHLC data if switching from candlestick to line chart
            if currentChartType == .candlestick {
                ohlcDataSubject.send([])
                errorMessageSubject.send(nil)
                print("📊 Switched to line chart - cleared OHLC data")
            }
        }
    }
    
    // MARK: - FIXED: Pure Combine Chart Data Fetching
    
    func fetchChartData(for range: String) {
        // FIXED: Cancel only chart data requests to prevent race conditions
        chartDataCancellable?.cancel()
        chartDataCancellable = nil
        
        currentRange = range
        
        guard let geckoID = geckoID else {
            errorMessageSubject.send("Chart data not available for \(coin.symbol)")
            return
        }
        
        let days = mapRangeToDays(range)
        
        // FIXED: Centralized cache checking with consistent key generation
        let cacheKey = "\(geckoID)_\(days)"
        print("🔑 Checking cache for key: \(cacheKey)")
        
        if let cachedChartData = CacheService.shared.getChartData(for: geckoID, currency: "usd", days: days),
           !cachedChartData.isEmpty {
            
            let processedData = processChartData(cachedChartData, for: days)
            chartPointsSubject.send(processedData)
            errorMessageSubject.send(nil)
            print("📦 ✅ Using cached chart data: \(processedData.count) points for \(range)")
            
            // FIXED: Only fetch OHLC if we're in candlestick mode AND don't have cached OHLC data
            if currentChartType == .candlestick {
                if let cachedOHLCData = CacheService.shared.getOHLCData(for: geckoID, currency: "usd", days: days),
                   !cachedOHLCData.isEmpty {
                    ohlcDataSubject.send(cachedOHLCData)
                    print("📦 ✅ Using cached OHLC data: \(cachedOHLCData.count) candles for \(range)")
                } else {
                    print("📊 Fetching missing OHLC data for \(range)")
                    fetchOHLCDataCombine(for: range)
                }
            }
            return
        }
        
        // Check rate limiting
        if requestManager.shouldPreferCache() {
            errorMessageSubject.send("API rate limiting active. Please try again in a moment.")
            return
        }
        
        print("🌐 No cache found - fetching fresh data for \(range)")
        
        // FIXED: Pure Combine request chain with dedicated cancellable
        isLoadingSubject.send(true)
        errorMessageSubject.send(nil)
        
        chartDataCancellable = coinManager.fetchChartData(for: geckoID, range: days, currency: "usd", priority: .high)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated)) // Background processing
            .map { [weak self] rawData -> [Double] in
                // Process data on background thread using Combine map
                return self?.processChartData(rawData, for: days) ?? []
            }
            .receive(on: DispatchQueue.main) // UI updates on main thread
            .handleEvents(
                receiveOutput: { [weak self] processedData in
                    self?.errorMessageSubject.send(nil)
                    print("📊 ✅ Chart updated with \(processedData.count) points for \(range)")
                }
            )
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingSubject.send(false)
                    
                    if case .failure(let error) = completion {
                        // FIXED: Better error handling for throttled requests
                        if let requestError = error as? RequestError, requestError == .throttled {
                            print("📊 Request throttled - not showing error")
                            // Don't show error for throttled requests, just stop loading
                        } else {
                            self?.handleError(error)
                        }
                    }
                },
                receiveValue: { [weak self] processedData in
                    guard let self = self else { return }
                    
                    self.chartPointsSubject.send(processedData)
                    
                    // Fetch OHLC if needed using Combine
                    if self.currentChartType == .candlestick {
                        self.fetchOHLCDataCombine(for: range)
                    }
                }
            )
    }
    
    // MARK: - FIXED: Pure Combine OHLC Data Fetching
    
    private func fetchOHLCDataCombine(for range: String) {
        guard let geckoID = geckoID else {
            print("⚠️ No geckoID available for OHLC data")
            return
        }
        
        // FIXED: Cancel any existing OHLC request
        ohlcDataCancellable?.cancel()
        ohlcDataCancellable = nil
        
        let days = mapRangeToDays(range)
        
        // Check cache first using Combine
        if let cachedOHLCData = CacheService.shared.getOHLCData(for: geckoID, currency: "usd", days: days),
           !cachedOHLCData.isEmpty {
            ohlcDataSubject.send(cachedOHLCData)
            print("📦 ✅ Using cached OHLC data: \(cachedOHLCData.count) candles for \(range)")
            return
        }
        
        // Check rate limiting
        let cooldownStatus = requestManager.getCooldownStatus()
        if cooldownStatus.isInCooldown {
            let remainingTime = cooldownStatus.remainingSeconds
            errorMessageSubject.send("API cooldown active (\(remainingTime)s). Candlestick data temporarily unavailable.")
            return
        }
        
        print("🌐 Fetching fresh OHLC data for \(range)")
        
        // FIXED: Pure Combine OHLC request with dedicated cancellable
        ohlcDataCancellable = coinManager.fetchOHLCData(for: geckoID, range: days, currency: "usd", priority: .normal)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] ohlcData in
                    print("📊 ✅ Fetched \(ohlcData.count) OHLC candles for \(range)")
                }
            )
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        // FIXED: Better error handling for throttled OHLC requests
                        if let requestError = error as? RequestError, requestError == .throttled {
                            print("📊 OHLC request throttled - not showing error")
                        } else {
                            self?.handleError(error)
                        }
                    }
                },
                receiveValue: { [weak self] ohlcData in
                    self?.ohlcDataSubject.send(ohlcData)
                }
            )
    }
    
    // MARK: - FIXED: Smart Auto-Refresh (Pure Combine)
    
    func smartAutoRefresh(for range: String) {
        let cooldownStatus = requestManager.getCooldownStatus()
        
        if cooldownStatus.isInCooldown {
            // FIXED: Use Combine Timer with proper subscription storage
            Timer.publish(every: Double(cooldownStatus.remainingSeconds), on: .main, in: .common)
                .autoconnect()
                .first() // Only fire once
                .sink { [weak self] _ in
                    print("🔄 Smart refresh: Cooldown ended, fetching fresh data")
                    self?.fetchChartData(for: range)
                }
                .store(in: &cancellables) // FIXED: Store in cancellables
        } else {
            // Check if we have recent cached data using Combine
            guard let geckoID = geckoID else { return }
            let days = mapRangeToDays(range)
            
            if CacheService.shared.getChartData(for: geckoID, currency: "usd", days: days) == nil {
                print("🔄 Smart refresh: No cached data, fetching fresh data")
                fetchChartData(for: range)
            } else {
                print("🔄 Smart refresh: Using existing cached data")
            }
        }
    }
    
    // MARK: - Error Handling (Pure Combine)
    
    private func handleError(_ error: Error) {
        let cooldownStatus = requestManager.getCooldownStatus()
        if cooldownStatus.isInCooldown {
            errorMessageSubject.send("API rate limit reached. Cooling down for \(cooldownStatus.remainingSeconds)s...")
        } else {
            errorMessageSubject.send(ErrorMessageProvider.shared.getChartErrorMessage(for: error, symbol: coin.symbol))
        }
        print("📊 Chart fetch failed: \(error)")
    }
    
    // MARK: - Data Processing (Pure Functions)
    
    private func processChartData(_ rawData: [Double], for days: String) -> [Double] {
        // Step 1: Validate data
        let validData = rawData.compactMap { value -> Double? in
            guard value.isFinite, value >= 0 else { return nil }
            return value
        }
        
        guard !validData.isEmpty else { return [] }
        
        // Step 2: Remove outliers (API errors, data spikes)
        let cleanedData = ChartSmoothingHelper.removeOutliers(validData)
        
        // Step 3: Apply smoothing before downsampling for better results (if enabled)
        let smoothedData = isSmoothingEnabled ? 
            ChartSmoothingHelper.applySmoothingToChartData(cleanedData, type: smoothingType, timeRange: days) : 
            cleanedData
        
        // Step 4: Optimize for performance (downsample if needed)
        let maxPoints = getMaxDataPointsForRange(days)
        if smoothedData.count > maxPoints {
            let step = max(1, smoothedData.count / maxPoints)
            let downsampledData = stride(from: 0, to: smoothedData.count, by: step).compactMap { index in
                index < smoothedData.count ? smoothedData[index] : nil
            }
            
            print("📊 Chart processing: \(rawData.count) → \(validData.count) → \(smoothedData.count) → \(downsampledData.count) points for \(days)")
            return downsampledData
        }
        
        print("📊 Chart processing: \(rawData.count) → \(validData.count) → \(smoothedData.count) points for \(days)")
        return smoothedData
    }
    
    private func getMaxDataPointsForRange(_ days: String) -> Int {
        switch days {
        case "1": return 200
        case "7": return 300
        case "30": return 400
        case "365": return 500
        default: return 300
        }
    }

    
    // MARK: - Chart Configuration
    
    // Toggle chart data smoothing on/off
    func setSmoothingEnabled(_ enabled: Bool) {
        isSmoothingEnabled = enabled
        // Refresh current chart data with new smoothing setting
        fetchChartData(for: currentRange)
        print("📊 Chart smoothing \(enabled ? "enabled" : "disabled")")
    }
    
    // Change smoothing algorithm
    func setSmoothingType(_ type: ChartSmoothingHelper.SmoothingType) {
        smoothingType = type
        // Refresh current chart data with new smoothing algorithm
        fetchChartData(for: currentRange)
        print("📊 Chart smoothing type changed to: \(type)")
    }
    
    var smoothingEnabled: Bool {
        return isSmoothingEnabled
    }
    
    var currentSmoothingType: ChartSmoothingHelper.SmoothingType {
        return smoothingType
    }
    
    // MARK: - Statistics (Pure Combine)
    
    func updateStatsRange(_ range: String) {
        selectedStatsRangeSubject.send(range)
        print("📊 Stats range updated to: \(range)")
    }
    
    private func getStats(for range: String) -> [StatItem] {
        var items: [StatItem] = []
        
        let currentCoinData = coinDataSubject.value
        guard let quote = currentCoinData.quote?["USD"] else { return items }
        
        // Core metrics
        if let marketCap = quote.marketCap {
            items.append(StatItem(title: "Market Cap", value: marketCap.abbreviatedString()))
        }
        
        if let volume24h = quote.volume24h {
            items.append(StatItem(title: "Volume (24h)", value: volume24h.abbreviatedString()))
        }
        
        // Volume change (24h) - NEW
        if let volumeChange24h = quote.volumeChange24h {
            let changeString = String(format: "%.2f%%", volumeChange24h)
            let color = volumeChange24h >= 0 ? UIColor.systemGreen : UIColor.systemRed
            items.append(StatItem(title: "Volume Change (24h)", value: changeString, valueColor: color))
        }
        
        // Fully Diluted Market Cap - NEW
        if let fullyDilutedMarketCap = quote.fullyDilutedMarketCap {
            items.append(StatItem(title: "Fully Diluted Market Cap", value: fullyDilutedMarketCap.abbreviatedString()))
        }
        
        // Market Cap Dominance - NEW
        if let dominance = quote.marketCapDominance {
            items.append(StatItem(title: "Market Dominance", value: String(format: "%.2f%%", dominance)))
        }
        
        // Time-specific changes
        addPercentageChangeStats(to: &items, from: quote, for: range)
        
        // Supply information
        if let circulating = currentCoinData.circulatingSupply {
            items.append(StatItem(title: "Circulating Supply", value: circulating.abbreviatedString()))
        }
        
        // Total Supply - NEW
        if let totalSupply = currentCoinData.totalSupply {
            items.append(StatItem(title: "Total Supply", value: totalSupply.abbreviatedString()))
        }
        
        // Max Supply - NEW
        if let maxSupply = currentCoinData.maxSupply {
            items.append(StatItem(title: "Max Supply", value: maxSupply.abbreviatedString()))
        } else if currentCoinData.infiniteSupply == true {
            items.append(StatItem(title: "Max Supply", value: "∞ (Infinite)", valueColor: .systemBlue))
        }
        
        // Market pairs - NEW
        if let numMarketPairs = currentCoinData.numMarketPairs {
            items.append(StatItem(title: "Market Pairs", value: "\(numMarketPairs)"))
        }
        
        // Rank
        items.append(StatItem(title: "Rank", value: "#\(currentCoinData.cmcRank)"))
        
        return items
    }
    
    private func addPercentageChangeStats(to items: inout [StatItem], from quote: Quote, for range: String) {
        switch range {
        case "24h":
            addPercentageStat(to: &items, title: "1h Change", percentage: quote.percentChange1h)
            addPercentageStat(to: &items, title: "24h Change", percentage: quote.percentChange24h)
        case "30d":
            addPercentageStat(to: &items, title: "7d Change", percentage: quote.percentChange7d)
            addPercentageStat(to: &items, title: "30d Change", percentage: quote.percentChange30d)
        case "1y":
            addPercentageStat(to: &items, title: "60d Change", percentage: quote.percentChange60d)
            addPercentageStat(to: &items, title: "90d Change", percentage: quote.percentChange90d)
        default:
            // Default view - show most common changes
            addPercentageStat(to: &items, title: "24h Change", percentage: quote.percentChange24h)
            addPercentageStat(to: &items, title: "7d Change", percentage: quote.percentChange7d)
            break
        }
    }
    
    private func addPercentageStat(to items: inout [StatItem], title: String, percentage: Double?) {
        guard let percentage = percentage else { return }
        
        let changeString = String(format: "%.2f%%", percentage)
        let color = percentage >= 0 ? UIColor.systemGreen : UIColor.systemRed
        items.append(StatItem(title: title, value: changeString, valueColor: color))
    }
    
    // MARK: - Utility
    
    func mapRangeToDays(_ range: String) -> String {
        switch range {
        case "24h": return "1"
        case "7d": return "7"
        case "30d": return "30"
        case "All", "365d": return "365"
        default: return "7"
        }
    }
    
    // MARK: - Combine Publisher Helpers
    
    var chartLoadingState: AnyPublisher<ChartLoadingState, Never> {
        Publishers.CombineLatest3(
            isLoading,
            chartPoints.map { !$0.isEmpty },
            errorMessage.map { $0 != nil }
        )
        .map { isLoading, hasData, hasError in
            if isLoading {
                return .loading
            } else if hasData {
                return .loaded
            } else if hasError {
                return .error
            } else {
                return .empty
            }
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    enum ChartLoadingState: Equatable {
        case loading
        case loaded
        case error
        case empty
    }
    
    // MARK: - FIXED: Proper Cleanup Methods
    
    func cancelAllRequests() {
        print("🛑 Cancelling all Combine requests for \(coin.symbol)")
        
        // FIXED: Cancel dedicated chart data requests first
        chartDataCancellable?.cancel()
        chartDataCancellable = nil
        ohlcDataCancellable?.cancel()
        ohlcDataCancellable = nil
        
        // Cancel all other Combine subscriptions
        cancellables.removeAll()
        
        // Reset loading states
        isLoadingSubject.send(false)
        
        print("✅ All Combine subscriptions cancelled for \(coin.symbol)")
    }
    
    deinit {
        print("🧹 CoinDetailsVM deinit - cleaning up Combine resources for \(coin.symbol)")
        
        // FIXED: Cancel dedicated chart data requests
        chartDataCancellable?.cancel()
        ohlcDataCancellable?.cancel()
        
        // Cancel all other subscriptions
        cancellables.removeAll()
        
        // Cancel any active timers
        cancelAllRequests() // This cancels refresh timers
        
        print("✅ CoinDetailsVM Combine cleanup completed for \(coin.symbol)")
    }
}









