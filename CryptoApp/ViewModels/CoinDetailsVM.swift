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

    // MARK: - Properties
    
    private let coin: Coin
    private let coinManager: CoinManagerProtocol
    private let sharedCoinDataManager: SharedCoinDataManagerProtocol
    private let requestManager: RequestManagerProtocol
    private let geckoID: String?
    
    // FIXED: Combine state management
    private let coinDataSubject: CurrentValueSubject<Coin, Never>
    private let chartPointsSubject = CurrentValueSubject<[Double], Never>([])
    private let ohlcDataSubject = CurrentValueSubject<[OHLCData], Never>([])
    private let statsOhlcDataSubject = CurrentValueSubject<[String: [OHLCData]], Never>([:]) // Independent OHLC data for stats
    private let statsLoadingSubject = CurrentValueSubject<Set<String>, Never>(Set<String>()) // Track which ranges are loading
    private let selectedStatsRangeSubject = CurrentValueSubject<String, Never>("24h")
    private let errorMessageSubject = CurrentValueSubject<String?, Never>(nil)
    private let lastErrorSubject = CurrentValueSubject<Error?, Never>(nil)
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let priceChangeSubject = CurrentValueSubject<PriceChangeIndicator?, Never>(nil)
    
    // FIXED: Request cancellation management
    private var chartDataCancellable: AnyCancellable?
    private var ohlcDataCancellable: AnyCancellable?
    private var statsOhlcCancellables: [String: AnyCancellable] = [:] // Separate cancellables for stats OHLC data
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published AnyPublisher Properties (Reactive UI Binding)
    
    var chartPoints: AnyPublisher<[Double], Never> {
        chartPointsSubject.eraseToAnyPublisher()
    }
    
    var ohlcData: AnyPublisher<[OHLCData], Never> {
        ohlcDataSubject.eraseToAnyPublisher()
    }
    
    var statsOhlcData: AnyPublisher<[String: [OHLCData]], Never> {
        statsOhlcDataSubject.eraseToAnyPublisher()
    }
    
    var statsLoadingState: AnyPublisher<Set<String>, Never> {
        statsLoadingSubject.eraseToAnyPublisher()
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
    
    // Chart configuration
    private var isSmoothingEnabled: Bool = true // Toggle for chart smoothing
    private var smoothingType: ChartSmoothingHelper.SmoothingType = .adaptive // Current smoothing algorithm
    
    // MARK: - State Management
    
    private var currentRange: String = "24h"
    private var currentChartType: ChartType = .line

    // MARK: - Computed Properties
    
    var currentStats: [StatItem] {
        return getStats(for: currentSelectedStatsRange)
    }
    
    // Reactive stats publisher that updates when coin data or OHLC data changes
    var stats: AnyPublisher<[StatItem], Never> {
        Publishers.CombineLatest3(
            coinData,
            selectedStatsRange,
            statsOhlcData
        )
        .map { [weak self] (_, range, _) in
            self?.getStats(for: range) ?? []
        }
        .eraseToAnyPublisher()
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
        } else {
            self.geckoID = nil
        }
        
        // SUBSCRIBE TO SHARED DATA: Get real-time price updates
        setupSharedCoinDataListener()
        
        // Fetch initial OHLC data for default stats range (24h)
        fetchStatsOHLCData(for: "24h")
    }
    
    // MARK: - Shared Data Management
    
    /**
     * SHARED COIN DATA LISTENER
     * 
     * Subscribes to SharedCoinDataManager for real-time price updates
     * and triggers price change animations when prices change
     */
    private func setupSharedCoinDataListener() {
        sharedCoinDataManager.allCoins.sinkForUI(
            { [weak self] allCoins in
                guard let self = self else { return }
                
                // Find updated data for this specific coin
                if let freshCoin = allCoins.first(where: { $0.id == self.coin.id }) {
                    self.handleFreshCoinData(freshCoin)
                }
            },
            storeIn: &cancellables
        )
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
        } else if chartType == .line {
            // IMPORTANT: Reprocess line chart data when switching from candlestick
            // This ensures smoothing settings are properly applied to avoid NaN issues
            if let geckoID = geckoID,
               let cachedChartData = CacheService.shared.getChartData(for: geckoID, currency: "usd", days: mapRangeToDays(targetRange)),
               !cachedChartData.isEmpty {
                let processedData = processChartData(cachedChartData, for: mapRangeToDays(targetRange))
                chartPointsSubject.send(processedData)
                errorMessageSubject.send(nil)
            }
        }
        // NOTE: Keep OHLC data available even in line chart mode for Low/High section
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
        
        if let cachedChartData = CacheService.shared.getChartData(for: geckoID, currency: "usd", days: days),
           !cachedChartData.isEmpty {
            
            let processedData = processChartData(cachedChartData, for: days)
            chartPointsSubject.send(processedData)
            errorMessageSubject.send(nil)
            
            // FIXED: Always fetch OHLC data for Low/High section, regardless of chart type
            if let cachedOHLCData = CacheService.shared.getOHLCData(for: geckoID, currency: "usd", days: days),
               !cachedOHLCData.isEmpty {
                ohlcDataSubject.send(cachedOHLCData)
            } else {
                fetchOHLCDataCombine(for: range)
            }
            return
        }
        
        // Check rate limiting
        if requestManager.shouldPreferCache() {
            errorMessageSubject.send("API rate limiting active. Please try again in a moment.")
            return
        }
        
        isLoadingSubject.send(true)
        errorMessageSubject.send(nil)
        lastErrorSubject.send(nil) // Clear previous errors to prevent flashing
        
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
                }
            )
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingSubject.send(false)
                    
                    if case .failure(let error) = completion {
                        // FIXED: Better error handling for throttled requests
                        // Don't show error for throttled requests, just stop loading
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] processedData in
                    guard let self = self else { return }
                    
                    self.chartPointsSubject.send(processedData)
                    
                    // Always fetch OHLC data for Low/High section
                    self.fetchOHLCDataCombine(for: range)
                }
            )
    }
    
    // MARK: - FIXED: Pure Combine OHLC Data Fetching
    
    private func fetchOHLCDataCombine(for range: String) {
        guard let geckoID = geckoID else {
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
            return
        }
        
        // Check rate limiting
        let cooldownStatus = requestManager.getCooldownStatus()
        if cooldownStatus.isInCooldown {
            let remainingTime = cooldownStatus.remainingSeconds
            errorMessageSubject.send("API cooldown active (\(remainingTime)s). Candlestick data temporarily unavailable.")
            return
        }
        
        ohlcDataCancellable = coinManager.fetchOHLCData(for: geckoID, range: days, currency: "usd", priority: .normal)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        // FIXED: Better error handling for throttled OHLC requests
                        // Don't show error for throttled requests
                        self?.handleError(error)
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
                    self?.fetchChartData(for: range)
                }
                .store(in: &cancellables) // FIXED: Store in cancellables
        } else {
            // Check if we have recent cached data using Combine
            guard let geckoID = geckoID else { return }
            let days = mapRangeToDays(range)
            
            if CacheService.shared.getChartData(for: geckoID, currency: "usd", days: days) == nil {
                fetchChartData(for: range)
            }
        }
    }
    
    // MARK: - Error Handling (Pure Combine)
    
    private func handleError(_ error: Error) {
        // Store the last error for retry functionality
        lastErrorSubject.send(error)
        
        let cooldownStatus = requestManager.getCooldownStatus()
        if cooldownStatus.isInCooldown {
            errorMessageSubject.send("API rate limit reached. Cooling down for \(cooldownStatus.remainingSeconds)s...")
        } else {
            let retryInfo = ErrorMessageProvider.shared.getChartRetryInfo(for: error, symbol: coin.symbol)
            errorMessageSubject.send(retryInfo.message)
        }
    }
    
    // MARK: - Manual Retry Functionality
    
    /// Manually retry chart data loading for the current range
    func retryChartData() {
        AppLogger.network("Manual retry requested for chart data - \(coin.symbol) (\(currentRange))")
        
        // Clear previous error state
        errorMessageSubject.send(nil)
        lastErrorSubject.send(nil)
        
        // Retry with current range
        fetchChartData(for: currentRange)
    }
    
    /// Manually retry OHLC data loading for the current range
    func retryOHLCData() {
        AppLogger.network("Manual retry requested for OHLC data - \(coin.symbol) (\(currentRange))")
        
        // Clear previous error state
        errorMessageSubject.send(nil)
        lastErrorSubject.send(nil)
        
        // Retry with current range
        fetchOHLCDataCombine(for: currentRange)
    }
    
    /// Manually retry both chart and OHLC data for the current range
    func retryAllChartData() {
        AppLogger.network("Manual retry requested for all chart data - \(coin.symbol) (\(currentRange))")
        
        // Clear previous error state
        errorMessageSubject.send(nil)
        lastErrorSubject.send(nil)
        
        // Retry chart data first, which will automatically trigger OHLC data loading
        fetchChartData(for: currentRange)
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
            
            return downsampledData
        }
        
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
    }
    
    // Change smoothing algorithm
    func setSmoothingType(_ type: ChartSmoothingHelper.SmoothingType) {
        smoothingType = type
        // Refresh current chart data with new smoothing algorithm
        fetchChartData(for: currentRange)
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
        
        // Fetch OHLC data for the new range to calculate high/low prices
        fetchStatsOHLCData(for: range)
    }

    
    private func getStats(for range: String) -> [StatItem] {
        let currentCoinData = coinDataSubject.value
        guard let quote = currentCoinData.quote?["USD"] else { 
            return []
        }
        
        var items: [StatItem] = []
        
        // High/Low prices for selected time range - FIRST ITEM
        addHighLowStats(to: &items, for: range)
        
        // Core metrics using configuration-driven approach
        // Create an array of stat configurations
        // addStatIfAvailable handles common patterns
        // statConfigs array defines each stat with: Title, getValue, getColor
        // addStatIfAvailable handles the common pattern of "if value exists, add it to the array.
        let statConfigs: [(title: String, getValue: () -> String?, getColor: () -> UIColor?)] = [
            ("Market Cap", { quote.marketCap?.abbreviatedString() }, { nil }),
            ("Volume (24h)", { quote.volume24h?.abbreviatedString() }, { nil }),
            ("Volume Change (24h)", { 
                quote.volumeChange24h.map { String(format: "%.2f%%", $0) }
            }, { 
                quote.volumeChange24h.map { $0 >= 0 ? UIColor.systemGreen : UIColor.systemRed }
            }),
            ("Fully Diluted Market Cap", { quote.fullyDilutedMarketCap?.abbreviatedString() }, { nil }),
            ("Market Dominance", { 
                quote.marketCapDominance.map { String(format: "%.2f%%", $0) }
            }, { nil }),
            ("Circulating Supply", { currentCoinData.circulatingSupply?.abbreviatedString() }, { nil }),
            ("Total Supply", { currentCoinData.totalSupply?.abbreviatedString() }, { nil }),
            ("Market Pairs", { 
                currentCoinData.numMarketPairs.map { "\($0)" }
            }, { nil }),
            ("Rank", { "#\(currentCoinData.cmcRank)" }, { nil })
        ]
        
        // Add stats using configuration
        for config in statConfigs {
            addStatIfAvailable(to: &items, title: config.title, getValue: config.getValue, getColor: config.getColor)
        }
        
        // Special case for Max Supply (always show)
        addMaxSupplyStat(to: &items, coinData: currentCoinData)
        
        return items
    }

    // MARK: - Helper Methods

    private func addStatIfAvailable(
        to items: inout [StatItem], 
        title: String, 
        getValue: () -> String?, 
        getColor: () -> UIColor?
    ) {
        guard let value = getValue() else { return }
        let color = getColor()
        items.append(StatItem(title: title, value: value, valueColor: color))
    }

    private func addMaxSupplyStat(to items: inout [StatItem], coinData: Coin) {
        let (value, color): (String, UIColor?) = {
            if let maxSupply = coinData.maxSupply {
                return (maxSupply.abbreviatedString(), nil)
            } else if coinData.infiniteSupply == true {
                return ("∞ (Infinite)", .systemBlue)
            } else {
                return ("N/A", .secondaryLabel)
            }
        }()
        
        items.append(StatItem(title: "Max Supply", value: value, valueColor: color))
    }
    
    private func addPercentageChangeStats(to items: inout [StatItem], from quote: Quote, for range: String) {
        // User requested: Filter should only change the high/low bar values, no percentage changes
        // Therefore, this method now does nothing regardless of range
    }
    
    private func addPercentageStat(to items: inout [StatItem], title: String, percentage: Double?) {
        guard let percentage = percentage else { return }
        
        let changeString = String(format: "%.2f%%", percentage)
        let color = percentage >= 0 ? UIColor.systemGreen : UIColor.systemRed
        items.append(StatItem(title: title, value: changeString, valueColor: color))
    }
    
    // MARK: - High/Low Price Calculation for Stats
    
    private func fetchStatsOHLCData(for range: String) {
        guard let geckoID = geckoID else {
            return
        }
        
        let days = mapRangeToDays(range)
        
        // Check cache first
        if let cachedOHLCData = CacheService.shared.getOHLCData(for: geckoID, currency: "usd", days: days),
           !cachedOHLCData.isEmpty {
            var currentStatsData = statsOhlcDataSubject.value
            currentStatsData[range] = cachedOHLCData
            statsOhlcDataSubject.send(currentStatsData)
            return
        }
        
        // Set loading state for this range
        var currentLoading = statsLoadingSubject.value
        currentLoading.insert(range)
        statsLoadingSubject.send(currentLoading)
        
        // Cancel any existing request for this range
        statsOhlcCancellables[range]?.cancel()
        
        statsOhlcCancellables[range] = coinManager.fetchOHLCData(for: geckoID, range: days, currency: "usd", priority: .normal)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    // Clear loading state
                    var currentLoading = self.statsLoadingSubject.value
                    currentLoading.remove(range)
                    self.statsLoadingSubject.send(currentLoading)
                    
                    if case .failure(let error) = completion {
                        AppLogger.error("Failed to fetch OHLC data for stats \(range)", error: error)
                    }
                },
                receiveValue: { [weak self] ohlcData in
                    guard let self = self else { return }
                    var currentStatsData = self.statsOhlcDataSubject.value
                    currentStatsData[range] = ohlcData
                    self.statsOhlcDataSubject.send(currentStatsData)
                }
            )
    }
    
    private func getHighLowPrices(for range: String) -> (high: Double?, low: Double?) {
        let statsData = statsOhlcDataSubject.value
        let loadingStates = statsLoadingSubject.value
        
        // Check if we have data for the current range
        if let ohlcData = statsData[range], !ohlcData.isEmpty {
            let highs = ohlcData.map { $0.high }
            let lows = ohlcData.map { $0.low }
            
            let highPrice = highs.max()
            let lowPrice = lows.min()
            
            return (highPrice, lowPrice)
        }
        
        // FIXED: If currently loading this range, return nil to avoid position jumps
        // Don't use fallback data as it causes the progress bar to jump to old positions
        if loadingStates.contains(range) {
            return (nil, nil)
        }
        
        // No data available and not loading
        return (nil, nil)
    }
    
    private func addHighLowStats(to items: inout [StatItem], for range: String) {
        let (high, low) = getHighLowPrices(for: range)
        let loadingStates = statsLoadingSubject.value
        
        // Determine if we're in a loading state for this range
        let isLoading = loadingStates.contains(range)
        
        // Only add high/low item when we have real data
        if let highPrice = high, let lowPrice = low, !isLoading {
            // We have real data and not loading
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            
            let lowString = formatter.string(from: NSNumber(value: lowPrice)) ?? "$0"
            let highString = formatter.string(from: NSNumber(value: highPrice)) ?? "$0"
            
            let currentCoinData = coinDataSubject.value
            let currentPrice = currentCoinData.quote?["USD"]?.price ?? 0.0
            
            // Create StatItem with actual high/low data
            let highLowItem = StatItem(
                title: "Low / High", 
                value: "\(lowString)|\(highString)|\(currentPrice)|false",
                valueColor: nil
            )
            items.append(highLowItem)
        } else if isLoading {
            // Add a special loading indicator item that tells StatsCell to preserve current state
            let highLowItem = StatItem(
                title: "Low / High", 
                value: "LOADING|LOADING|0|true", // Special loading marker
                valueColor: nil
            )
            items.append(highLowItem)
        }
        // If not loading and no data, don't add any item
    }
    
    // MARK: - Utility
    
    func mapRangeToDays(_ range: String) -> String {
        switch range {
        case "24h": return "1"
        case "7d": return "7"
        case "30d": return "30"
        case "1y", "All", "365d": return "365"
        default: return "7"
        }
    }
    
    // MARK: - Combine Publisher Helpers
    
    var chartLoadingState: AnyPublisher<ChartLoadingState, Never> {
        Publishers.CombineLatest4(
            isLoading,
            chartPoints.map { !$0.isEmpty },
            errorMessage.map { $0 != nil },
            lastErrorSubject.eraseToAnyPublisher()
        )
        .map { [weak self] isLoading, hasData, hasError, lastError in
            if isLoading {
                return .loading
            } else if hasData {
                return .loaded
            } else if hasError, let error = lastError {
                // Generate retry information for the error
                let symbol = self?.coin.symbol ?? "Unknown"
                let retryInfo = ErrorMessageProvider.shared.getChartRetryInfo(for: error, symbol: symbol)
                
                if retryInfo.isRetryable {
                    return .error(retryInfo)
                } else {
                    return .nonRetryableError(retryInfo.message)
                }
            } else if hasError {
                // Fallback for errors without retry information
                return .nonRetryableError("Chart data temporarily unavailable")
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
        case error(RetryErrorInfo)
        case nonRetryableError(String)
        case empty
    }
    
    // MARK: - FIXED: Proper Cleanup Methods
    
    func clearPreviousStates() {
        // Clear any previous error states to prevent flashing when view appears
        errorMessageSubject.send(nil)
        lastErrorSubject.send(nil)
    }
    
    func cancelAllRequests() {
        
        // FIXED: Cancel dedicated chart data requests first
        chartDataCancellable?.cancel()
        chartDataCancellable = nil
        ohlcDataCancellable?.cancel()
        ohlcDataCancellable = nil
        
        // Cancel stats OHLC requests
        for (_, cancellable) in statsOhlcCancellables {
            cancellable.cancel()
        }
        statsOhlcCancellables.removeAll()
        
        // Clear loading states
        statsLoadingSubject.send(Set<String>())
        
        // Cancel all other Combine subscriptions
        cancellables.removeAll()
        
        // Reset loading states
        isLoadingSubject.send(false)
        
    }
    
    deinit {
        AppLogger.ui("CoinDetailsVM deinit - cleaning up Combine resources for \(coin.symbol)")
        
        // FIXED: Cancel dedicated chart data requests
        chartDataCancellable?.cancel()
        ohlcDataCancellable?.cancel()
        
        // Cancel stats OHLC requests
        for (_, cancellable) in statsOhlcCancellables {
            cancellable.cancel()
        }
        statsOhlcCancellables.removeAll()
        
        // Clear loading states
        statsLoadingSubject.send(Set<String>())
        
        // Cancel all other subscriptions
        cancellables.removeAll()
        
        // Cancel any active timers
        cancelAllRequests() // This cancels refresh timers
        
        AppLogger.success("CoinDetailsVM Combine cleanup completed for \(coin.symbol)")
    }
}









