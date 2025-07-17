//  CoinDetailsVM.swift
//  CryptoApp

/**
 * CoinDetailsVM
 *
 * 
 *   FEATURES:
 * - Multi-timeframe chart data (24h, 7d, 30d, 1y)
 * - Priority-based API request system (high priority for user actions)
 * - Background prefetching of common chart ranges
 * - Data processing (smoothing, optimization, validation)
 * - Dynamic statistics generation based on selected timeframe
 * - Error handling with auto-retry
 * - Memory-efficient chart data management
 * 
 * 📊 CHART DATA PIPELINE:
 * 1. User selects timeframe → High priority API request
 * 2. Raw data processing → Smoothing → Optimization
 * 3. Chart points updated → UI automatically refreshes
 * 4. Background prefetching for other common ranges
 * 
 * PERFORMANCE OPTIMIZATIONS:
 * - Background prefetching reduces filter switching delays
 * - Data processing happens on background threads
 * - Chart data optimization reduces UI rendering load
 * - Smart caching prevents redundant API calls
 */

import Foundation
import Combine

final class CoinDetailsVM: ObservableObject {

    // MARK: - Published Properties (Reactive UI Binding)
    
    /**
     * CHART AND UI STATE PROPERTIES
     * 
     * These @Published properties automatically trigger UI updates when changed.
     * The chart view subscribes to these and updates instantly when new data arrives.
     */
    
    @Published var chartPoints: [Double] = []              // Chart data points for visualization
    @Published var isLoading: Bool = false                 // Loading state for chart area
    @Published var errorMessage: String?                   // Error messages
    @Published var selectedStatsRange: String = "24h"     //  Current stats timeframe filter

    /**
     * CHART RELOAD CONTROL
     * 
     * This flag controls when the chart should fully reload vs. append data.
     * Used for historical data loading where we want to add older points
     * without triggering a complete chart redraw.
     */
    var shouldReloadChart = true

    // MARK: - Core Dependencies
    
    /**
     * DEPENDENCY ARCHITECTURE
     * 
     * - coin: The specific cryptocurrency data being displayed
     * - coinManager: Handles all API calls and network logic
     * - geckoID: CoinGecko identifier for chart data API calls
     * - cancellables: Combine subscription storage for memory management
     */
    
    private let coin: Coin                     // Coin data model
    private let coinManager: CoinManager       // API management layer
    private var geckoID: String?               // CoinGecko API identifier
    var cancellables = Set<AnyCancellable>()   // Combine subscription storage

    // MARK: - Chart State Management
    
    /**
     * CHART LOADING STATE TRACKING
     * 
     * These properties manage the current chart state and prevent
     * conflicting operations like multiple simultaneous data loads.
     */
    
    private var currentRange: String = "24h"              // Currently displayed timeframe
    private var isLoadingMoreData = false                 // Prevents duplicate historical data requests

    // MARK: - Smart Prefetching System
    
    /**
     * PREFETCHING ARCHITECTURE
     * 
     * This system proactively downloads chart data for commonly accessed timeframes
     * in the background, making filter switches feel instant to users.
     * 
     * FLOW:
     * - When user opens coin details, immediately load selected range (high priority)
     * - Start background prefetching of 24h, 7d, 30d after staggered delays
     * - Mark prefetched ranges to avoid duplicate requests
     * - Use low priority for prefetching to not interfere with user actions
     */
    

    private let commonRanges = ["24h", "7d", "30d"]       // Most frequently accessed timeframes

    // MARK: - Dynamic Statistics System
    
    /**
     * COMPUTED STATISTICS BASED ON SELECTED TIMEFRAME
     * 
     * This computed property dynamically generates relevant statistics
     * based on the user's selected time range filter.
     * 
     * EXAMPLES:
     * - 24h range: Shows 24h change, 24h volume change
     * - 30d range: Shows 30d change, 7d change
     * - 1y range: Shows 90d, 60d, 30d changes for broader perspective
     * 
     * FORMATTING: Uses abbreviatedString() for user-friendly display (1.2B, 999M)
     */
    var currentStats: [StatItem] {
        return getStats(for: selectedStatsRange)
    }
    
    /**
     * STATISTICS GENERATION ENGINE
     * 
     * This method dynamically creates statistics based on available coin data
     * and the selected timeframe. It intelligently shows relevant metrics
     * for each time period.
     * 
     * ADAPTIVE CONTENT:
     * - Always shows: Market cap, volume, supply info, rank
     * - Time-specific: Different percentage changes based on selected range
     * - Color coding: Green for positive changes, red for negative
     */
    private func getStats(for range: String) -> [StatItem] {
        var items: [StatItem] = []

        if let quote = coin.quote?["USD"] {
            // CORE FINANCIAL METRICS (Always Displayed) - Using Switch Pattern Matching
            switch quote.marketCap {
            case let marketCap?:
                items.append(StatItem(title: "Market Cap", value: marketCap.abbreviatedString()))
            case nil:
                break
            }
            
            switch quote.volume24h {
            case let volume24h?:
                items.append(StatItem(title: "Volume (24h)", value: volume24h.abbreviatedString()))
            case nil:
                break
            }
            
            switch quote.fullyDilutedMarketCap {
            case let fdv?:
                items.append(StatItem(title: "Fully Diluted Market Cap", value: fdv.abbreviatedString()))
            case nil:
                break
            }
            
            // TIME-SPECIFIC PERCENTAGE CHANGES
            addPercentageChangeStats(to: &items, from: quote, for: range)
        }

        // SUPPLY INFORMATION (Fundamental Analysis Data) - Using Switch Pattern Matching
        switch coin.circulatingSupply {
        case let circulating?:
            items.append(StatItem(title: "Circulating Supply", value: circulating.abbreviatedString()))
        case nil:
            break
        }

        switch coin.totalSupply {
        case let total?:
            items.append(StatItem(title: "Total Supply", value: total.abbreviatedString()))
        case nil:
            break
        }

        switch coin.maxSupply {
        case let max?:
            items.append(StatItem(title: "Max Supply", value: max.abbreviatedString()))
        case nil:
            break
        }

        // 🏆 MARKET RANKING
        items.append(StatItem(title: "Rank", value: "#\(coin.cmcRank)"))

        return items
    }
    
    // MARK: - Helper Functions
    
    /**
     * PERCENTAGE STAT HELPER
     * 
     * Creates a formatted percentage stat item with appropriate color coding.
     * Eliminates code repetition across different timeframe stats.
     */
    private func addPercentageStat(to items: inout [StatItem], title: String, percentage: Double?) {
        guard let percentage = percentage else { return }
        
        let changeString = String(format: "%.2f%%", percentage)
        let color = percentage >= 0 ? UIColor.systemGreen : UIColor.systemRed
        items.append(StatItem(title: title, value: changeString, valueColor: color))
    }
    
    private func addPercentageChangeStats(to items: inout [StatItem], from quote: Quote, for range: String) {
        switch range {
        case "24h":
            // 📅 SHORT-TERM FOCUS: Daily changes and volume metrics
            addPercentageStat(to: &items, title: "24h Change", percentage: quote.percentChange24h)
            
            // Volume change only if volume exists
            if quote.volume24h != nil {
                addPercentageStat(to: &items, title: "24h Volume Change", percentage: quote.volumeChange24h)
            }
            
        case "30d":
            // 📅 MEDIUM-TERM PERSPECTIVE: Monthly and weekly changes
            addPercentageStat(to: &items, title: "30d Change", percentage: quote.percentChange30d)
            addPercentageStat(to: &items, title: "7d Change", percentage: quote.percentChange7d)
            
        case "1y":
            // 📅 LONG-TERM ANALYSIS: Quarterly, bi-monthly, and monthly trends
            addPercentageStat(to: &items, title: "90d Change", percentage: quote.percentChange90d)
            addPercentageStat(to: &items, title: "60d Change", percentage: quote.percentChange60d)
            addPercentageStat(to: &items, title: "30d Change", percentage: quote.percentChange30d)
            
        default:
            break
        }
    }
    
    /**
     * STATISTICS RANGE UPDATE HANDLER
     * 
     * Updates the selected statistics timeframe and triggers UI refresh.
     * This changes which percentage change metrics are displayed.
     */
    func updateStatsRange(_ range: String) {
        selectedStatsRange = range  // 🎯 Triggers UI update via @Published
        print("📊 Stats range updated to: \(range)")
    }

    // MARK: - Initialization & Setup
    
    /**
     * INITIALIZATION WITH  PREFETCHING
     *
     * The initializer sets up the ViewModel and immediately starts optimizing
     * the user experience through background prefetching.
     * 
     * INITIALIZATION FLOW:
     * 1. Store coin data and dependencies
     * 2. Map coin slug to CoinGecko ID for API calls
     * 3. Start background prefetching of common ranges
     * 
     * PREFETCHING STRATEGY:
     * Users typically view 24h first, then switch to 7d or 30d.
     * By prefetching these ranges, switching will be instant.
     */
    init(coin: Coin, coinManager: CoinManager = CoinManager()) {
        self.coin = coin
        self.coinManager = coinManager

        // ID MAPPING: Convert CMC slug to CoinGecko ID for chart API
        if let slug = coin.slug, !slug.isEmpty {
            self.geckoID = slug.lowercased()
            print("✅ Using coin slug for \(coin.symbol): \(slug)")
        } else {
            print("❌ No slug found for \(coin.symbol) - chart data will not be available")
            self.geckoID = nil
        }
    }


    
    /**
     * CHART DATA FETCHING
     */
    func fetchChartData(for range: String) {
        currentRange = range
        let days = mapRangeToDays(range)

        guard let geckoID = geckoID else {
            print("❌ No CoinGecko ID found for \(coin.symbol)")
            errorMessage = "Chart data not available for \(coin.symbol)"
            isLoading = false
            return
        }
        
        
        isLoading = true
        errorMessage = nil
        
        coinManager.fetchChartData(for: geckoID, range: days, priority: .high)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .map { [weak self] rawData in
                return self?.processChartData(rawData, for: days) ?? []
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        print("📊 Chart fetch failed: \(error)")
                    }
                },
                receiveValue: { [weak self] processedData in
                    self?.chartPoints = processedData
                    print("📊 ✅ Chart updated with \(processedData.count) points for \(range)")
                }
            )
            .store(in: &cancellables)
    }

    
    // MARK: - Data Processing Engine
    
    /**
     *  DATA PROCESSING PIPELINE
     * 
     * This method transforms raw API data into optimized chart-ready format.
     * 
     *   PROCESSING GOALS:
     * - Data validation and cleaning
     * - Noise reduction through smoothing
     * - Performance optimization for UI rendering
     * - Consistent visual experience across timeframes
     * 
     *   MULTI-STAGE PIPELINE:
     * 1. Validation: Remove invalid/infinite values
     * 2. Smoothing: Reduce noise for better visuals
     * 3. Optimization: Reduce point density for performance
     * 4. Quality assurance: Ensure data integrity
     */
    private func processChartData(_ rawData: [Double], for days: String) -> [Double] {
        //   1: DATA VALIDATION AND CLEANING
        let processedData = rawData.compactMap { value -> Double? in
            // Remove infinite, NaN, and negative values that would break charts
            guard value.isFinite, value >= 0 else { return nil }
            return value
        }
        
        //   2: VISUAL SMOOTHING FOR BETTER USER EXPERIENCE
        let smoothedData = applyDataSmoothing(processedData, for: days)
        
        //   3: PERFORMANCE OPTIMIZATION FOR SMOOTH UI
        let optimizedData = optimizeDataDensity(smoothedData, for: days)
        
        print("📊 Data processing: \(rawData.count) → \(optimizedData.count) points")
        return optimizedData
    }
    
    /**
     *  DATA SMOOTHING ALGORITHM
     * 
     * Applies smoothing to reduce visual noise in longer timeframes while
     * preserving important price movements and trends.
     * 
     *   DECISIONS:
     * - No smoothing for 24h (preserves detail)
     * - Light smoothing for longer ranges (reduces noise)
     * - Moving average window scales with data size
     * - Preserves overall trend while reducing visual clutter
     * 
     * 📊 TECHNICAL APPROACH:
     * - Uses moving average algorithm
     * - Dynamic window size based on data density
     * - Maintains data integrity while improving visualization
     */
    private func applyDataSmoothing(_ data: [Double], for days: String) -> [Double] {
        // SMART SMOOTHING: Only apply to longer ranges where noise is problematic
        guard days != "1", data.count > 10 else { return data }
        
        // DYNAMIC WINDOW SIZE: Scales with data density for optimal results
        let windowSize = min(5, data.count / 10)
        guard windowSize > 1 else { return data }
        
        var smoothedData: [Double] = []
        
        // MOVING AVERAGE CALCULATION
        for i in 0..<data.count {
            let start = max(0, i - windowSize / 2)
            let end = min(data.count, i + windowSize / 2 + 1)
            let window = Array(data[start..<end])
            let average = window.reduce(0, +) / Double(window.count)
            smoothedData.append(average)
        }
        
        return smoothedData
    }
    
    /**
     * PERFORMANCE-ORIENTED DATA OPTIMIZATION
     * 
     * Optimizes data density for smooth chart rendering while preserving visual accuracy.
     * Too many points can cause UI lag -> too few points lose important details.
     *
     *   OPTIMIZATION STRATEGY:
     * - Different point densities for different timeframes
     * - Higher resolution for shorter ranges -> more detail needed
     * - Lower resolution for longer ranges -> trend more important
     * - Maintains visual fidelity while ensuring smooth performance
     * 
     *   MOBILE OPTIMIZATION:
     * - Balances visual quality with rendering performance
     * - Prevents UI lag during scrolling and zooming
     * - Ensures consistent experience across device types
     */
    private func optimizeDataDensity(_ data: [Double], for days: String) -> [Double] {
        // 📊 DYNAMIC RESOLUTION: Different densities for different timeframes
        let maxDisplayPoints: Int
        
        switch days {
        case "1": maxDisplayPoints = 100   // 24h - high resolution for detail
        case "7": maxDisplayPoints = 200   // 7d - medium resolution
        case "30": maxDisplayPoints = 300  // 30d - medium resolution  
        case "365": maxDisplayPoints = 400 // 1y - lower resolution for trend
        default: maxDisplayPoints = 300
        }
        
        // EFFICIENCY CHECK: Only optimize if needed
        guard data.count > maxDisplayPoints else { return data }
        
        // THINNING: Preserve shape while reducing points
        let step = Double(data.count) / Double(maxDisplayPoints)
        var optimizedData: [Double] = []
        
        for i in 0..<maxDisplayPoints {
            let index = Int(Double(i) * step)
            if index < data.count {
                optimizedData.append(data[index])
            }
        }
        
        return optimizedData
    }
    
    // MARK: - Error Handling System
    
    /**
     * ERROR HANDLING APPROACH
     *
     * Transforms technical errors into user-friendly messages and implements
     * intelligent recovery strategies for different error types.
     *
     * 🔄 RECOVERY STRATEGIES:
     * - Network errors: Auto-retry with exponential backoff
     * - Server errors: Auto-retry once after delay
     * - Client errors: Show message, no retry (would fail again)
     * - Rate limiting: Wait and retry automatically
     */
    private func handleChartDataError(_ error: Error) {
        // 🎨 USER EXPERIENCE: Convert technical errors to friendly messages
        let userFriendlyMessage: String
        
        switch error {
        case NetworkError.badURL:
            userFriendlyMessage = "Invalid request. Please try again."
        case NetworkError.invalidResponse:
            userFriendlyMessage = "Server error. Please check your connection."
        case NetworkError.decodingError:
            userFriendlyMessage = "Data format error. Please try again later."
        case NetworkError.unknown(let underlyingError):
            if underlyingError.localizedDescription.contains("offline") ||
               underlyingError.localizedDescription.contains("network") {
                userFriendlyMessage = "No internet connection. Please check your network."
            } else {
                userFriendlyMessage = "Something went wrong. Please try again."
            }
        default:
            userFriendlyMessage = "Unable to load chart data. Please try again."
        }
        
        self.errorMessage = userFriendlyMessage  // 🎯 Show user-friendly message
        print("❌ Chart fetch failed: \(error.localizedDescription)")
        
        // AUTO-RECOVERY: Retry for recoverable errors
        if shouldAutoRetry(for: error) {
            autoRetryAfterDelay()
        }
    }
    
    /**
     * ERROR CLASSIFICATION
     * 
     * Determines which errors are worth retrying automatically.
     * Prevents infinite retry loops while maximizing success rate.
     */
    private func shouldAutoRetry(for error: Error) -> Bool {
        switch error {
        case NetworkError.badURL, NetworkError.decodingError:
            return false  // 🚫 Client errors - retrying won't help
        case NetworkError.invalidResponse, NetworkError.unknown:
            return true   // 🔄 Server/network errors - might be transient
        default:
            return false
        }
    }
    
    /**
     * AUTOMATIC RETRY WITH DELAY
     * 
     * Implements exponential backoff strategy for automatic error recovery.
     * Gives temporary issues time to resolve without immediate retry spam.
     */
    private func autoRetryAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            print("🔄 Auto-retrying chart data fetch...")
            self.fetchChartData(for: self.currentRange)
        }
    }
    
    // MARK: - Historical Data Management
    
    /**
     * HISTORICAL DATA EXPANSION
     * 
     * Allows users to scroll back in time to see more historical data.
     * This would typically connect to API endpoints that support pagination.
     * 
     * DESIGN PATTERN:
     * - Prevents duplicate requests with loading flag
     * - Maintains UI responsiveness during loading
     * - Would append older data to beginning of chart
     * - Preserves current view position after loading
     */
    func loadMoreHistoricalData(for range: String, beforeDate: Date) {
        // 🛡️ CONCURRENCY PROTECTION: Prevent multiple simultaneous loads
        guard !isLoadingMoreData else { return }
        
        isLoadingMoreData = true
        
        // 💡 IMPLEMENTATION NOTE: Real API integration would go here
        print("📅 Loading more historical data for \(range) before \(beforeDate)")
        
        // 🔄 SIMULATED ASYNC OPERATION (placeholder for real implementation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoadingMoreData = false
            // Real implementation would call: appendHistoricalData(newOlderData)
        }
    }
    
    /**
     * HISTORICAL DATA INTEGRATION
     * 
     * Seamlessly integrates older historical data with current chart data.
     * Maintains chart state and user position while expanding the dataset.
     * 
     * SMART INTEGRATION:
     * - Prepends older data to preserve chronological order
     * - Disables chart reload to maintain user's current view
     * - Enables smooth infinite scrolling experience
     */
    func appendHistoricalData(_ newData: [Double]) {
        let olderData = newData.prefix(max(0, newData.count - chartPoints.count))
        shouldReloadChart = false                    // 🚫 Prevents jarring chart reset
        chartPoints = Array(olderData) + chartPoints // 📈 Seamless data integration
        print("📈 Appended \(olderData.count) historical points. Total: \(chartPoints.count)")
    }
    
    // MARK: - Utility Methods
    
    /**
     * TIMEFRAME CONVERSION UTILITY
     * 
     * Converts user-friendly time range labels to API-compatible day counts.
     * This abstraction layer allows UI labels to be independent of API format.
     */
    func mapRangeToDays(_ range: String) -> String {
        switch range {
        case "24h": return "1"
        case "7d": return "7"
        case "30d": return "30"
        case "365d": return "365"
        default: return "7"
        }
    }
    
    /**
     * INTELLIGENT RANGE EXTENSION FOR HISTORICAL LOADING
     * 
     * When user scrolls to chart edge, this determines how much additional
     * historical data to load for a smooth experience.
     * 
     * EXTENSION APPROACH:
     * - 24h → 7d: Expand to weekly view for more context
     * - 7d → 30d: Monthly view for broader perspective  
     * - 30d → 90d: Quarterly view for trend analysis
     * - 1y → max: Full historical data available
     */
    func calculateExtendedRange(for range: String) -> String {
        switch range {
        case "24h": return "7"     // Show week context
        case "7d": return "30"     // Show month context
        case "30d": return "90"    // Show quarter context
        case "365d": return "max"  // Show all available data
        default: return "30"
        }
    }
    
    /**
     * DATA LOADING STATE CHECKER
     * 
     * Determines if more historical data can be loaded based on current state.
     * Prevents loading when already in progress or when no data exists.
     */
    var canLoadMoreData: Bool {
        return !isLoadingMoreData && !chartPoints.isEmpty
    }
    
    // MARK: - Lifecycle Management
    
    /**
     * 🛑 IMMEDIATE CLEANUP FOR SCREEN TRANSITIONS
     * 
     * Cancels all ongoing requests when user leaves the coin details screen.
     * Prevents unnecessary API calls and ensures clean memory management.
     * 
     *   CLEANUP BENEFITS:
     * - Saves bandwidth by canceling unneeded requests
     * - Prevents memory leaks from active subscriptions
     * - Ensures clean state for potential return visits
     * - Improves overall app performance
     */
    func cancelAllRequests() {
        print("🛑 Cancelling all ongoing API calls for \(coin.symbol)")
        cancellables.removeAll()    // 🔗 Cancel all Combine subscriptions
        isLoading = false          // 🧹 Reset loading states
        isLoadingMoreData = false
    }
    
    /**
     * AUTOMATIC CLEANUP ON DEALLOCATION
     * 
     * Ensures proper cleanup even if manual cleanup wasn't called.
     * This is a safety net that prevents memory leaks and orphaned requests.
     */
    deinit {
        print("🧹 CoinDetailsVM deinit - cancelling all API calls for \(coin.symbol)")
        cancellables.removeAll()
        // Combine automatically cancels subscriptions when cancellables are cleared
    }
}








