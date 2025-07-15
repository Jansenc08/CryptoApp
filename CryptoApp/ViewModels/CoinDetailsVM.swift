//  CoinDetailsVM.swift
//  CryptoApp

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
    @Published var selectedStatsRange: String = "24h"  // Track selected stats time range

    var shouldReloadChart = true

    private let coin: Coin // holds current coin to hold data
    private let coinManager: CoinManager // holds current manager to hold data
    private var geckoID: String? // store resolved CoinGecko ID

    var cancellables = Set<AnyCancellable>() //  stores combine subscriptions

    // Using CacheService for chart data caching

    private var currentRange: String = "24h"
    private var isLoadingMoreData = false // prevents duplicate calls when scrolling left

    // MARK: - Prefetching Support
    private var prefetchedRanges: Set<String> = []
    private let commonRanges = ["24h", "7d", "30d"] // Most commonly accessed ranges

    // Dynamically creates a list of stats based on available data and selected time range
    // Returns Data such as Market cap, volume, fdv etc.
    // uses helper class: formattedWithAbbreviations() to convert values to 1.23B, 999K etc
    var currentStats: [StatItem] {
        return getStats(for: selectedStatsRange)
    }
    
    // Generate stats based on selected time range
    private func getStats(for range: String) -> [StatItem] {
        var items: [StatItem] = []

        if let quote = coin.quote?["USD"] {
            // Always show current market data
            if let marketCap = quote.marketCap {
                items.append(StatItem(title: "Market Cap", value: marketCap.abbreviatedString()))
            }
            if let volume24h = quote.volume24h {
                items.append(StatItem(title: "Volume (24h)", value: volume24h.abbreviatedString()))
            }
            if let fdv = quote.fullyDilutedMarketCap {
                items.append(StatItem(title: "Fully Diluted Market Cap", value: fdv.abbreviatedString()))
            }
            
            // Add time-based percentage changes based on selected range
            addPercentageChangeStats(to: &items, from: quote, for: range)
        }

        // Supply information (always shown)
        if let circulating = coin.circulatingSupply {
            items.append(StatItem(title: "Circulating Supply", value: circulating.abbreviatedString()))
        }

        if let total = coin.totalSupply {
            items.append(StatItem(title: "Total Supply", value: total.abbreviatedString()))
        }

        if let max = coin.maxSupply {
            items.append(StatItem(title: "Max Supply", value: max.abbreviatedString()))
        }

        items.append(StatItem(title: "Rank", value: "#\(coin.cmcRank)"))

        return items
    }
    
    // Add percentage change stats based on selected time range
    private func addPercentageChangeStats(to items: inout [StatItem], from quote: Quote, for range: String) {
        switch range {
        case "24h":
            if let change24h = quote.percentChange24h {
                let changeString = String(format: "%.2f%%", change24h)
                let color = change24h >= 0 ? UIColor.systemGreen : UIColor.systemRed
                items.append(StatItem(title: "24h Change", value: changeString, valueColor: color))
            }
            if let _ = quote.volume24h, let volumeChange24h = quote.volumeChange24h {
                let changeString = String(format: "%.2f%%", volumeChange24h)
                let color = volumeChange24h >= 0 ? UIColor.systemGreen : UIColor.systemRed
                items.append(StatItem(title: "24h Volume Change", value: changeString, valueColor: color))
            }
            
        case "30d":
            if let change30d = quote.percentChange30d {
                let changeString = String(format: "%.2f%%", change30d)
                let color = change30d >= 0 ? UIColor.systemGreen : UIColor.systemRed
                items.append(StatItem(title: "30d Change", value: changeString, valueColor: color))
            }
            if let change7d = quote.percentChange7d {
                let changeString = String(format: "%.2f%%", change7d)
                let color = change7d >= 0 ? UIColor.systemGreen : UIColor.systemRed
                items.append(StatItem(title: "7d Change", value: changeString, valueColor: color))
            }
            
        case "1y":
            if let change90d = quote.percentChange90d {
                let changeString = String(format: "%.2f%%", change90d)
                let color = change90d >= 0 ? UIColor.systemGreen : UIColor.systemRed
                items.append(StatItem(title: "90d Change", value: changeString, valueColor: color))
            }
            if let change60d = quote.percentChange60d {
                let changeString = String(format: "%.2f%%", change60d)
                let color = change60d >= 0 ? UIColor.systemGreen : UIColor.systemRed
                items.append(StatItem(title: "60d Change", value: changeString, valueColor: color))
            }
            if let change30d = quote.percentChange30d {
                let changeString = String(format: "%.2f%%", change30d)
                let color = change30d >= 0 ? UIColor.systemGreen : UIColor.systemRed
                items.append(StatItem(title: "30d Change", value: changeString, valueColor: color))
            }
            
        default:
            break
        }
    }
    
    // Method to update selected stats range
    func updateStatsRange(_ range: String) {
        selectedStatsRange = range
        print("📊 Stats range updated to: \(range)")
    }

    init(coin: Coin, coinManager: CoinManager = CoinManager()) {
        self.coin = coin
        self.coinManager = coinManager

        // Use coin slug directly -> needed for mapping
        if let slug = coin.slug {
            self.geckoID = slug.lowercased()
            print("✅ Using coin slug for \(coin.symbol): \(slug)")
            // Start prefetching common ranges in background
            // Background prefetch 24h, 7d, 30d
            self.startPrefetchingCommonRanges()
        } else {
            print("❌ No slug found for \(coin.symbol)")
        }
    }

    // MARK: - Prefetching Implementation (Optimized for Filter Performance)
    // Schedules multiple background prefetches for commonly used ranges like "24h", "7d", and "30d" with staggered delays
    // These is happening sequentially
    // Called once during init()
    // Calls prefetchSingleRange(...) for each range
    private func startPrefetchingCommonRanges() {
        guard let geckoID = geckoID else { return }
        
        // Instead of waiting 20 seconds, start prefetching immediately with staggered delays
        // This means when users click filters, the data is likely already cached
        let prefetchPlan = [
            ("24h", 5.0),   // 5 seconds - most common after current
            ("7d", 10.0),   // 10 seconds - second most common
            ("30d", 15.0)   // 15 seconds - third most common
        ]
        
        for (range, delay) in prefetchPlan {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + delay) {
                // Only prefetch if user is still on this page
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.chartPoints.isEmpty else { return }
                    
                    // Skip if already prefetched - no duplicate work
                    if self.prefetchedRanges.contains(range) {
                        print("📦 Skipping prefetch for \(range) - already cached")
                        return
                    }
                    
                    print("🔄 Starting prefetch for \(geckoID) - \(range)")
                    self.prefetchSingleRange(geckoID: geckoID, range: range)
                }
            }
        }
    }

    // Method for single-range prefetching
    // Called by startPrefetchingCommonRanges()
    // Fetches + processes + marks range as prefetched
    private func prefetchSingleRange(geckoID: String, range: String) {
        let days = mapRangeToDays(range)
        
        // Use LOW priority for background prefetching - this ensures it doesn't interfere 
        // with user-initiated filter changes, but still happens in the background
        coinManager.fetchChartData(for: geckoID, range: days, priority: .low)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .map { [weak self] rawData in

                return self?.processChartData(rawData, for: days) ?? []
            }
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("📦 Prefetch failed for \(range): \(error)")
                    } else {
                        print("📦 ✅ Prefetch completed for \(range)")
                        // Mark as prefetched so we don't try again
                        self?.prefetchedRanges.insert(range)
                    }
                },
                receiveValue: { processedData in
                    print("📦 Prefetched and processed \(processedData.count) points for \(range)")
                }
            )
            .store(in: &cancellables)
    }
    
    // High priority chart data fetching for user filter changes
    func fetchChartData(for range: String) {
        currentRange = range
        let days = mapRangeToDays(range)

        guard let id = geckoID else {
            print("❌ No CoinGecko ID found for \(coin.symbol)")
            return
        }
        // Mark all user filter changes as HIGH PRIORITY
        // This means they jump to the front of the request queue and only wait 2 seconds.
        print("📊 ‼️ HIGH PRIORITY: User filter change for \(id) - \(range)")
        
        // Execute immediately with HIGH priority for user-initiated filter changes
        // This is what makes filter switching much faster!
        fetchChartDataFromAPI(geckoID: id, days: days, priority: .high)
    }
    
    // Simplified API call - CacheService handles all caching logic
    // This method fetches chart data from the API for a specific coin and time range, handles caching, loading states, and UI updates.
    // Supports priority-based fetching (e.g., high for user filters, low for background), and ensures background processing is done efficiently.
    private func fetchChartDataFromAPI(geckoID: String, days: String, priority: RequestPriority = .normal) {
        isLoading = true
        errorMessage = nil
        
        // Logging to show priority level (For debugging purposes)
        let priorityLabel = priority == .high ? "‼️ HIGH PRIORITY" : "🟡 NORMAL"
        print("🌐 \(priorityLabel) API call for \(geckoID) with \(days) days")
        
        // Background Threads: Data Processing
        // Pass the priority parameter all the way through to CoinManager
        coinManager.fetchChartData(for: geckoID, range: days, priority: priority)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated)) // Network on background
            .map { [weak self] rawData in
                // Process data in background
                return self?.processChartData(rawData, for: days) ?? []
            }
            .retryWithExponentialBackoff(maxRetries: 3, initialDelay: 1.0)
            .receive(on: DispatchQueue.main) // Switch back on main thread for UI updates 
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleChartDataError(error)
                    }
                },
                receiveValue: { [weak self] processedData in
                    guard let self = self else { return }
                    print("✅ \(priorityLabel) Processed \(processedData.count) data points")
                    self.shouldReloadChart = true
                    self.chartPoints = processedData
                    self.errorMessage = nil // Clear any previous errors
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Background Data Processing
    
    private func processChartData(_ rawData: [Double], for days: String) -> [Double] {
        // Perform heavy data processing on background queue
        let processedData = rawData.compactMap { value -> Double? in
            // Remove invalid values
            guard value.isFinite, value >= 0 else { return nil }
            return value
        }
        
        // Apply smoothing for longer time ranges
        let smoothedData = applyDataSmoothing(processedData, for: days)
        
        // Optimize data density for UI performance
        let optimizedData = optimizeDataDensity(smoothedData, for: days)
        
        print("📊 Data processing: \(rawData.count) → \(optimizedData.count) points")
        return optimizedData
    }
    
    private func applyDataSmoothing(_ data: [Double], for days: String) -> [Double] {
        // Apply smoothing only for longer time ranges to reduce noise
        guard days != "1", data.count > 10 else { return data }
        
        let windowSize = min(5, data.count / 10)
        guard windowSize > 1 else { return data }
        
        var smoothedData: [Double] = []
        
        for i in 0..<data.count {
            let start = max(0, i - windowSize / 2)
            let end = min(data.count, i + windowSize / 2 + 1)
            let window = Array(data[start..<end])
            let average = window.reduce(0, +) / Double(window.count)
            smoothedData.append(average)
        }
        
        return smoothedData
    }
    
    private func optimizeDataDensity(_ data: [Double], for days: String) -> [Double] {
        // Optimize data density based on chart display needs
        let maxDisplayPoints: Int
        
        switch days {
        case "1": maxDisplayPoints = 100  // 24h - high resolution
        case "7": maxDisplayPoints = 200  // 7d - medium resolution
        case "30": maxDisplayPoints = 300 // 30d - medium resolution
        case "365": maxDisplayPoints = 400 // 1y - lower resolution
        default: maxDisplayPoints = 300
        }
        
        guard data.count > maxDisplayPoints else { return data }
        
        // Use data thinning to reduce points while preserving shape
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
    
    private func handleChartDataError(_ error: Error) {
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
        
        self.errorMessage = userFriendlyMessage
        print("❌ Chart fetch failed: \(error.localizedDescription)")
        
        // Optional: Automatically retry after a delay for certain errors
        if shouldAutoRetry(for: error) {
            autoRetryAfterDelay()
        }
    }
    
    private func shouldAutoRetry(for error: Error) -> Bool {
        // Auto-retry for network-related errors, but not for client errors
        switch error {
        case NetworkError.badURL, NetworkError.decodingError:
            return false
        case NetworkError.invalidResponse, NetworkError.unknown:
            return true
        default:
            return false
        }
    }
    
    private func autoRetryAfterDelay() {
        // Wait 5 seconds before automatic retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            print("🔄 Auto-retrying chart data fetch...")
            self.fetchChartData(for: self.currentRange)
        }
    }
    
    // MARK: - Historical Data Loading (Optimized)
    func loadMoreHistoricalData(for range: String, beforeDate: Date) {
        // Prevent multiple simultaneous loads
        guard !isLoadingMoreData else { return }
        
        isLoadingMoreData = true
        
        // For now, this is a placeholder - in a real app, API endpoints is needed
        // that support pagination with date parameters
        print("📅 Loading more historical data for \(range) before \(beforeDate)")
        
        // Simulate async load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoadingMoreData = false
            // In real implementation, append new data to chartPoints
        }
    }
    
    // Takes older historical points and prepends them to chartPoints.
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
    

    
    var canLoadMoreData: Bool {
        return !isLoadingMoreData && !chartPoints.isEmpty
    }
    
    // MARK: - Cleanup
    
    // Method to manually cancel all ongoing API calls
    // Can be called from viewWillDisappear for immediate cleanup
    func cancelAllRequests() {
        print("🛑 Cancelling all ongoing API calls for \(coin.symbol)")
        cancellables.removeAll()
        isLoading = false
        isLoadingMoreData = false
    }
    
    deinit {
        print("🧹 CoinDetailsVM deinit - cancelling all API calls for \(coin.symbol)")
        cancellables.removeAll()
        // This automatically cancels all ongoing network requests and subscriptions
    }
}








