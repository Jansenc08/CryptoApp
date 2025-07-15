//
//  CoinListVM.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import Foundation
import Combine

final class CoinListVM: ObservableObject {

    // MARK: - Published Properties (Observed by the UI)

    @Published var coins: [Coin] = []                      // All coins displayed in the collection view
    @Published var coinLogos: [Int: String] = [:]          // Coin ID to logo URL mapping
    @Published var isLoading: Bool = false                 // True during initial data load
    @Published var isLoadingMore: Bool = false             // True during pagination
    @Published var errorMessage: String?                   // Displayable error message (binds to alerts)
    @Published var updatedCoinIds: Set<Int> = []           // Track which coins had price changes
    @Published var filterState: FilterState = .defaultState // Current filter state for UI binding

    // MARK: - Sorting Properties
    
    private var currentSortColumn: CryptoSortColumn = CryptoSortColumn.price
    private var currentSortOrder: CryptoSortOrder = CryptoSortOrder.descending
    
    // MARK: - Dependencies

    private let coinManager: CoinManager                   // Handles all API calls
    private var cancellables = Set<AnyCancellable>()       // Stores Combine subscriptions
    private let persistenceService = PersistenceService.shared // Handles offline persistence

    // MARK: - Pagination Properties

    private let itemsPerPage = 20                          // Number of coins to load per API request
    private var currentPage = 1                            // Current page number (used to calculate API offset)
    private var canLoadMore = true                         // Flag that indicates if more data can be fetched
    private var fullFilteredCoins: [Coin] = []             // Complete filtered and sorted coin list for pagination
    
    // MARK: - Optimization Properties
    
    private let loadMoreSubject = PassthroughSubject<String, Never>()  // Subject for debouncing load more requests with convert parameter
    private var lastFetchTime: Date?                       // Track when we last fetched data
    private let minimumFetchInterval: TimeInterval = 2.0   // Minimum time between fetches (2 seconds)

    // MARK: - Init

    init(coinManager: CoinManager = CoinManager()) {
        self.coinManager = coinManager
        setupLoadMoreDebouncing()
    }
    
    // MARK: - Setup
    
    private func setupLoadMoreDebouncing() {
        // Debounce load more requests to prevent excessive API calls during rapid scrolling
        loadMoreSubject
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)  // Reduced from 0.5 to 0.3 seconds for better responsiveness
            .sink { [weak self] convert in
                self?.performLoadMoreCoins(convert: convert)
            }
            .store(in: &cancellables)
    }

    // MARK: - Filter Management
    
    func updatePriceChangeFilter(_ filter: PriceChangeFilter) {
        let newState = FilterState(priceChangeFilter: filter, topCoinsFilter: filterState.topCoinsFilter)
        updateFilterState(newState)
    }
    
    func updateTopCoinsFilter(_ filter: TopCoinsFilter) {
        let newState = FilterState(priceChangeFilter: filterState.priceChangeFilter, topCoinsFilter: filter)
        updateFilterState(newState)
    }
    
    // MARK: - Sorting Management
    
    func updateSorting(column: CryptoSortColumn, order: CryptoSortOrder) {
        currentSortColumn = column
        currentSortOrder = order
        
        print("🔄 Applying sort: \(columnName(for: column)) - \(order == CryptoSortOrder.descending ? "Descending" : "Ascending")")
        
        // Apply sorting to current data
        applySortingToCurrentData()
    }
    
    // Getter methods for current sort state
    func getCurrentSortColumn() -> CryptoSortColumn {
        return currentSortColumn
    }
    
    func getCurrentSortOrder() -> CryptoSortOrder {
        return currentSortOrder
    }
    

    
    private func columnName(for column: CryptoSortColumn) -> String {
        switch column {
        case CryptoSortColumn.rank:
            return "Rank"
        case CryptoSortColumn.marketCap:
            return "Market Cap"
        case CryptoSortColumn.price:
            return "Price"
        case CryptoSortColumn.priceChange:
            return "\(filterState.priceChangeFilter.shortDisplayName) Change"
        default:
            return "Unknown"
        }
    }
    
    private func applySortingToCurrentData() {
        print("🔧 applySortingToCurrentData | fullFilteredCoins: \(fullFilteredCoins.count), coins: \(coins.count)")
        
        // If we have no full data but have displayed coins, use those
        if fullFilteredCoins.isEmpty && !coins.isEmpty {
            print("🔧 Using displayed coins for sorting (\(coins.count) coins)")
            fullFilteredCoins = coins
        }
        
        // Don't sort if we have no data at all
        guard !fullFilteredCoins.isEmpty else {
            print("⚠️ No data to sort")
            return
        }
        
        print("🔧 Sorting \(fullFilteredCoins.count) coins by \(columnName(for: currentSortColumn)) \(currentSortOrder == CryptoSortOrder.descending ? "DESC" : "ASC")")
        
        // Sort the full filtered coins list
        fullFilteredCoins = sortCoins(fullFilteredCoins)
        
        // Update the displayed coins (first page)
        let pageSize = itemsPerPage
        let sortedDisplayCoins = Array(fullFilteredCoins.prefix(pageSize))
        coins = sortedDisplayCoins
        
        print("✅ Sort applied: Displaying \(sortedDisplayCoins.count) coins")
    }
    
    private func updateFilterState(_ newState: FilterState) {
        // Don't trigger unnecessary updates
        guard newState != filterState else { return }
        
        let oldState = filterState
        filterState = newState
        
        print("🎯 FILTER CHANGE: \(oldState.topCoinsFilter.displayName) + \(oldState.priceChangeFilter.displayName) → \(newState.topCoinsFilter.displayName) + \(newState.priceChangeFilter.displayName)")
        
        // Clear relevant caches when filters change to ensure fresh data
        // This is important because cached data might not match new filter criteria
        if oldState.topCoinsFilter != newState.topCoinsFilter {
            print("🗑️ Clearing cache due to Top Coins filter change")
            persistenceService.clearCache() // Clear offline cache
        }
        
        // Reset pagination for filtered results
        currentPage = 1
        canLoadMore = true
        coins = []
        fullFilteredCoins = []
        
        print("🔄 Fetching fresh data with new filters...")
        
        // Fetch data with new filters using HIGH priority for immediate response
        fetchCoins(convert: "USD", priority: .high)
    }

    // MARK: - Initial Data Fetch

    func fetchCoins(convert: String = "USD", priority: RequestPriority = .normal, onFinish: (() -> Void)? = nil) {
        print("🔧 VM.fetchCoins | Called with completion: \(onFinish != nil)")
        print("🔧 VM.fetchCoins | Current sort: \(columnName(for: currentSortColumn)) \(currentSortOrder == CryptoSortOrder.descending ? "DESC" : "ASC")")
        
        // Check if we should skip this fetch due to recent activity
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            print("⏰ VM.fetchCoins | Skipped due to recent fetch")
            onFinish?()
            return
        }
        
        // Only use offline cached data if it matches current filter state AND cache is not expired
        // This prevents using cached data that was fetched with different filter parameters
        if !persistenceService.isCacheExpired(), 
           let offlineData = persistenceService.getOfflineData(),
           filterState == .defaultState { // Only use cache for default filter state
            print("💾 VM.fetchCoins | Using cached offline data (default filters)")
            currentPage = 1
            canLoadMore = true
            
            // Apply sorting to cached data BEFORE setting coins to prevent UI flash
            let sortedCachedCoins = sortCoins(offlineData.coins)
            coins = sortedCachedCoins
            coinLogos = offlineData.logos
            
            onFinish?()
            return
        }
        
        // When filters are applied or cache is expired, always fetch fresh data
        if filterState != .defaultState {
            print("🎯 VM.fetchCoins | Filters applied (\(filterState.topCoinsFilter.displayName) + \(filterState.priceChangeFilter.displayName)) - fetching fresh data")
        }
        
        // Reset state for a fresh fetch
        print("\n🌟 Initial Load | Fetching coin data...")
        currentPage = 1
        canLoadMore = true
        coins = []
        isLoading = true
        errorMessage = nil
        lastFetchTime = Date()

        // BACKEND FILTERING APPROACH:
        // 1. Backend: Get top N coins by market cap (ranks 1-100/200/500)
        // 2. Local: Sort those specific coins by selected price change metric
        // This ensures we get exactly the top ranked coins, sorted by price performance
        
        let topCoinsLimit = filterState.topCoinsFilter.rawValue
        let filterDescription = "\(filterState.topCoinsFilter.displayName) sorted by \(filterState.priceChangeFilter.displayName)"
        
        print("🎯 Filter: \(filterDescription)")
        print("🔄 Backend: Fetching top \(topCoinsLimit) coins by market cap (ranks 1-\(topCoinsLimit))...")
        
        // Backend: Get top N coins by market cap with all quote data
        coinManager.getTopCoins(
            limit: topCoinsLimit,
            convert: convert,
            start: 1,
            sortType: "market_cap",
            sortDir: "desc", 
            priority: priority
        )
        .map { [weak self] topCoinsByMarketCap -> [Coin] in
            guard let self = self else { return topCoinsByMarketCap }
            
            print("✅ Backend: Got \(topCoinsByMarketCap.count) coins (ranks 1-\(topCoinsByMarketCap.count))")
            
            // Debug: Print first few coins to verify we got top coins by market cap
            if topCoinsByMarketCap.count > 0 {
                let topFew = Array(topCoinsByMarketCap.prefix(3))
                let topCoinsDebug = topFew.map { "\($0.name) (ID:\($0.id), Rank:\($0.cmcRank))" }.joined(separator: ", ")
                print("🔍 Top coins by market cap: \(topCoinsDebug)")
            }
            
            print("🔄 Local: Applying current sort (\(self.columnName(for: self.currentSortColumn)) - \(self.currentSortOrder == CryptoSortOrder.descending ? "Descending" : "Ascending"))...")
            
            // Apply current sorting to the fetched coins
            let sortedCoins = self.sortCoins(topCoinsByMarketCap)
            
            // Debug: Print top few after sorting
            if sortedCoins.count > 0 {
                let topSorted = Array(sortedCoins.prefix(3))
                let sortedDebug = topSorted.map { coin in
                    let sortValue = self.getSortValue(for: coin, column: self.currentSortColumn)
                    return "\(coin.name) (\(sortValue))"
                }.joined(separator: ", ")
                print("🔍 Top by \(self.columnName(for: self.currentSortColumn)): \(sortedDebug)")
            }
            
            print("✅ Local: Sorting complete!")
            print("📊 Result: Top \(sortedCoins.count) coins by market cap, ordered by \(self.columnName(for: self.currentSortColumn))")
            
            return sortedCoins
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            if case let .failure(error) = completion {
                print("❌ VM.fetchCoins | Error: \(error.localizedDescription)")
                self?.errorMessage = error.localizedDescription
                self?.canLoadMore = false
                
                // Try to load offline data as fallback
                if let offlineData = self?.persistenceService.getOfflineData() {
                    // Apply sorting to fallback data BEFORE setting coins to prevent UI flash
                    let sortedFallbackCoins = self?.sortCoins(offlineData.coins) ?? offlineData.coins
                    self?.coins = sortedFallbackCoins
                    self?.coinLogos = offlineData.logos
                    self?.errorMessage = "Using offline data due to network error"
                }
            }
            print("🔄 VM.fetchCoins | Calling completion handler")
            onFinish?()
        } receiveValue: { [weak self] filteredAndSortedCoins in
            guard let self = self else { return }
            
            // Take only the first page for initial display
            let pageSize = self.itemsPerPage
            let initialCoins = Array(filteredAndSortedCoins.prefix(pageSize))
            self.coins = initialCoins

            // Store the full filtered list for pagination
            self.fullFilteredCoins = filteredAndSortedCoins
            
            // Only allow loading more if we have more coins available
            self.canLoadMore = filteredAndSortedCoins.count > pageSize

            print("📱 UI: Displaying \(initialCoins.count) coins (page 1 of \(filteredAndSortedCoins.count) total)")

            // Start fetching logos for the coins (only if we don't already have them) with LOW priority
            let ids = initialCoins.map { $0.id }
            self.fetchCoinLogosIfNeeded(forIDs: ids)
            
            // Save data for offline use (only if using default filters)
            if self.filterState == .defaultState {
                self.persistenceService.saveCoinList(initialCoins)
            }
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    private func sortCoins(_ coins: [Coin]) -> [Coin] {
        return coins.sorted { coin1, coin2 in
                            let ascending = (currentSortOrder == CryptoSortOrder.ascending)
        
        switch currentSortColumn {
        case CryptoSortColumn.rank:
                return ascending ? (coin1.cmcRank < coin2.cmcRank) : (coin1.cmcRank > coin2.cmcRank)
                
            case CryptoSortColumn.marketCap:
                let marketCap1 = coin1.quote?["USD"]?.marketCap ?? 0
                let marketCap2 = coin2.quote?["USD"]?.marketCap ?? 0
                return ascending ? (marketCap1 < marketCap2) : (marketCap1 > marketCap2)
                
            case CryptoSortColumn.price:
                let price1 = coin1.quote?["USD"]?.price ?? 0
                let price2 = coin2.quote?["USD"]?.price ?? 0
                return ascending ? (price1 < price2) : (price1 > price2)
                
            case CryptoSortColumn.priceChange:
                let change1 = getPriceChangeValue(for: coin1)
                let change2 = getPriceChangeValue(for: coin2)
                return ascending ? (change1 < change2) : (change1 > change2)
                
            default:
                // Fallback to rank sorting
                return coin1.cmcRank < coin2.cmcRank
            }
        }
    }
    
    private func getPriceChangeValue(for coin: Coin) -> Double {
        guard let quote = coin.quote?["USD"] else { return 0.0 }
        
        switch filterState.priceChangeFilter {
        case .oneHour:
            return quote.percentChange1h ?? 0.0
        case .twentyFourHours:
            return quote.percentChange24h ?? 0.0
        case .sevenDays:
            return quote.percentChange7d ?? 0.0
        case .thirtyDays:
            return quote.percentChange30d ?? 0.0
        }
    }
    
    private func getSortValue(for coin: Coin, column: CryptoSortColumn) -> String {
        switch column {
        case CryptoSortColumn.rank:
            return "#\(coin.cmcRank)"
        case CryptoSortColumn.marketCap:
            let marketCap = coin.quote?["USD"]?.marketCap ?? 0
            return "$\(marketCap.abbreviatedString())"
        case CryptoSortColumn.price:
            let price = coin.quote?["USD"]?.price ?? 0
            return String(format: "$%.2f", price)
        case CryptoSortColumn.priceChange:
            let change = getPriceChangeValue(for: coin)
            return String(format: "%.2f%%", change)
        default:
            return "N/A"
        }
    }

    // MARK: - Pagination (Triggered on Scroll)

    func loadMoreCoins(convert: String = "USD") {
        // Use debounced approach to prevent excessive API calls
        loadMoreSubject.send(convert)
    }
    
    private func performLoadMoreCoins(convert: String = "USD") {
        // Request guarding
        // Prevent multiple calls from running concurrently
        guard canLoadMore && !isLoadingMore && !isLoading else { 
            print("🚫 Pagination | Blocked | CanLoad: \(canLoadMore) | Loading: \(isLoading) | LoadingMore: \(isLoadingMore)")
            return 
        }

        // Use local pagination with cached sorted data
        let currentCount = coins.count
        let totalAvailable = fullFilteredCoins.count
        
        if currentCount >= totalAvailable {
            canLoadMore = false
            print("🛑 Pagination | All coins loaded | \(currentCount)/\(totalAvailable)")
            return
        }

        // Advance to next page and start loading
        currentPage += 1
        isLoadingMore = true
        errorMessage = nil
        
        print("📖 Pagination | Loading page \(currentPage) | Current: \(coins.count) coins")

        // Simulate brief loading delay for UX, then append next batch from cached data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            
            let startIndex = self.coins.count
            let endIndex = min(startIndex + self.itemsPerPage, self.fullFilteredCoins.count)
            let newCoins = Array(self.fullFilteredCoins[startIndex..<endIndex])
            
            self.coins.append(contentsOf: newCoins)
            self.isLoadingMore = false
            
            let totalCoins = self.coins.count
            print("✅ Pagination | Added \(newCoins.count) coins | Total: \(totalCoins)")

            // Check if we can load more
            if totalCoins >= self.fullFilteredCoins.count {
                self.canLoadMore = false
                print("🏁 Pagination | Complete | Total: \(totalCoins)/\(self.fullFilteredCoins.count)")
            }

            // Fetch logos for newly displayed coins
            let newIds = newCoins.map { $0.id }
            self.fetchCoinLogosIfNeeded(forIDs: newIds)
        }
    }

    // MARK: - Fetch Coin Logos (Called after loading coins)

    func fetchCoinLogos(forIDs ids: [Int]) {
        // Use LOW priority for logo fetching
        coinManager.getCoinLogos(forIDs: ids, priority: .low)
            .sink { [weak self] logos in
                // Merge new logos with existing ones (new overrides old if needed)
                self?.coinLogos.merge(logos) { _, new in new }
            }
            .store(in: &cancellables)
    }
    
    private func fetchCoinLogosIfNeeded(forIDs ids: [Int]) {
        // Only fetch logos for coins we don't already have
        let missingLogoIds = ids.filter { coinLogos[$0] == nil }
        
        print("🖼️ CoinListVM.fetchCoinLogosIfNeeded | Total IDs: \(ids.count), Missing: \(missingLogoIds.count)")
        print("🖼️ Current logo count: \(coinLogos.count)")
        
        if !missingLogoIds.isEmpty {
            print("🌐 CoinListVM | Fetching logos for missing IDs: \(missingLogoIds)")
            // Use LOW priority for logo fetching
            coinManager.getCoinLogos(forIDs: missingLogoIds, priority: .low)
                .sink { [weak self] logos in
                    print("📥 CoinListVM | Received \(logos.count) new logos, merging with existing \(self?.coinLogos.count ?? 0)")
                    // Merge new logos with existing ones (new overrides old if needed)
                    self?.coinLogos.merge(logos) { _, new in new }
                    print("📊 CoinListVM | Total logos after merge: \(self?.coinLogos.count ?? 0)")
                    
                    // Save updated logos for offline use
                    self?.persistenceService.saveCoinLogos(self?.coinLogos ?? [:])
                }
                .store(in: &cancellables)
        } else {
            print("✅ CoinListVM | All logos already available, no fetch needed")
        }
    }

    // MARK: - Periodic Price Update (Used by auto-refresh)

    func fetchPriceUpdates(completion: @escaping () -> Void) {
        // Don't fetch updates if we're already loading data
        guard !isLoading && !isLoadingMore else {
            completion()
            return
        }
        
        let ids = coins.map { $0.id } // Get all coin IDs currently shown
        
        // Don't make empty requests
        guard !ids.isEmpty else {
            completion()
            return
        }

        // Use LOW priority for background auto-refresh
        // I use low priority for auto-refresh because it's happening in the background
        // and shouldn't interfere with user-initiated actions like filter changes
        coinManager.getQuotes(for: ids, priority: .low)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    // Only show error if it's not a throttling error (which is expected)
                    if !error.localizedDescription.contains("throttled") {
                        self?.errorMessage = error.localizedDescription
                    }
                }
                completion()
            } receiveValue: { [weak self] updatedQuotes in
                guard let self = self else { return }

                // Track which coins actually changed
                var changedCoinIds = Set<Int>()
                
                print("🔍 Price Check | Analyzing \(self.coins.count) total coins...")
                
                // Update price-related data in each coin and track changes
                for i in 0..<self.coins.count {
                    let id = self.coins[i].id
                    if let updated = updatedQuotes[id] {
                        // Compare old and new prices
                        let oldPrice = self.coins[i].quote?["USD"]?.price
                        let newPrice = updated.price
                        let oldPercentChange = self.coins[i].quote?["USD"]?.percentChange24h
                        let newPercentChange = updated.percentChange24h
                        
                        // Check if price or percentage change actually changed (any difference)
                        let priceChanged = oldPrice != newPrice
                        let percentChanged = oldPercentChange != newPercentChange
                        
                        if priceChanged || percentChanged {
                            self.coins[i].quote?["USD"] = updated
                            changedCoinIds.insert(id)
                        }
                    }
                }
                
                // Summary and UI update
                if !changedCoinIds.isEmpty {
                    self.updatedCoinIds = changedCoinIds
                    print("📊 Data Update | \(changedCoinIds.count) coins changed (full list) | IDs: \(Array(changedCoinIds).sorted())")
                    print("─────────────────────────────────────────")
                } else {
                    print("📊 Data Update | No changes detected (full list)")
                    print("─────────────────────────────────────────")
                }
                
                completion()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Visibility-based Price Updates (More efficient)
    
    func fetchPriceUpdatesForVisibleCoins(_ visibleIds: [Int], completion: @escaping () -> Void) {
        // Don't fetch updates if we're already loading data
        guard !isLoading && !isLoadingMore else {
            completion()
            return
        }
        
        // Don't make empty requests
        guard !visibleIds.isEmpty else {
            completion()
            return
        }

        // Use LOW priority for background auto-refresh
        // Same logic as above - background auto-refresh should never interfere with user actions
        coinManager.getQuotes(for: visibleIds, priority: .low)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    // Only show error if it's not a throttling error (which is expected)
                    if !error.localizedDescription.contains("throttled") {
                        self?.errorMessage = error.localizedDescription
                    }
                }
                completion()
            } receiveValue: { [weak self] updatedQuotes in
                guard let self = self else { return }

                // Track which coins actually changed
                var changedCoinIds = Set<Int>()
                
                print("🔍 Price Check | Analyzing \(visibleIds.count) visible coins...")
                
                // Update price-related data only for visible coins and track changes
                for i in 0..<self.coins.count {
                    let id = self.coins[i].id
                    if visibleIds.contains(id), let updated = updatedQuotes[id] {
                        // Compare old and new prices
                        let oldPrice = self.coins[i].quote?["USD"]?.price
                        let newPrice = updated.price
                        let oldPercentChange = self.coins[i].quote?["USD"]?.percentChange24h
                        let newPercentChange = updated.percentChange24h
                        
                        // Check if price or percentage change actually changed (any difference)
                        let priceChanged = oldPrice != newPrice
                        let percentChanged = oldPercentChange != newPercentChange
                        
                        if priceChanged || percentChanged {
                            self.coins[i].quote?["USD"] = updated
                            changedCoinIds.insert(id)
                            
                            // Concise logging with better formatting
                            let oldPriceValue = oldPrice ?? 0
                            let newPriceValue = newPrice ?? 0
                            let priceDiff = abs(newPriceValue - oldPriceValue)
                            
                            let changeType = priceChanged && percentChanged ? "Both" : (priceChanged ? "Price" : "Percent")
                            let priceDisplay = String(format: "%.6f", oldPriceValue) + " → " + String(format: "%.6f", newPriceValue)
                            
                            print("💰 Coin \(id) | \(changeType) | $\(priceDisplay) | Δ\(String(format: "%.6f", priceDiff))")
                        }
                    }
                }
                
                // Summary and UI update
                if !changedCoinIds.isEmpty {
                    self.updatedCoinIds = changedCoinIds
                    print("📱 UI Update | \(changedCoinIds.count) visible coins | IDs: \(Array(changedCoinIds).sorted())")
                    print("─────────────────────────────────────────")
                } else {
                    print("📱 UI Update | No changes detected (visible coins)")
                    print("─────────────────────────────────────────")
                }
                
                completion()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Management
    
    func clearUpdatedCoinIds() {
        updatedCoinIds.removeAll()
    }
    
    // MARK: - Cleanup
    
    // Method to manually cancel all ongoing API calls
    // Can be called from viewWillDisappear for immediate cleanup
    func cancelAllRequests() {
        print("🛑 Cancelling all ongoing API calls for coin list")
        cancellables.removeAll()
        isLoading = false
        isLoadingMore = false // Assuming isRefreshing is not used in this file, but keeping it for consistency
    }
    
    deinit {
        print("🧹 CoinListVM deinit - cleaning up subscriptions")
        cancellables.removeAll()
    }
}
