//
//  CoinListVM.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import Foundation
import Combine

/**
 * CoinListVM
 * 
 *  ARCHITECTURE PATTERN: MVVM (Model-View-ViewModel)
 * - This ViewModel sits between the UI (CoinListVC) and business logic (CoinManager)
 * - It handles all state management, data transformation, and business logic
 * - Uses AnyPublisher properties to automatically notify the UI of changes via Combine
 * 
 *  REACTIVE PROGRAMMING: Uses Combine framework for data flow
 * - AnyPublisher properties trigger UI updates automatically when data changes
 * - Combine publishers chain API calls and handle async operations
 * - Automatic memory management via cancellables
 * 
 *  KEY FEATURES:
 * - Real-time price updates every 15 seconds
 * - Smart pagination (20 coins per page)
 * - Multi-layer caching (memory, disk, offline)
 * - Priority-based API request management
 * - Intelligent filtering and sorting
 * - Robust error handling and offline support
 */
final class CoinListVM: ObservableObject {

    // MARK: - Private Subjects (Internal State Management)
    
    /**
     * REACTIVE STATE MANAGEMENT WITH SUBJECTS
     * 
     * Using CurrentValueSubject for state that needs current values
     * Using PassthroughSubject for events and notifications
     * This gives us more control over when and how values are published
     */
    
    private let coinsSubject = CurrentValueSubject<[Coin], Never>([])
    private let coinLogosSubject = CurrentValueSubject<[Int: String], Never>([:])
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let isLoadingMoreSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = CurrentValueSubject<String?, Never>(nil)
    private let updatedCoinIdsSubject = CurrentValueSubject<Set<Int>, Never>([])
    private let filterStateSubject = CurrentValueSubject<FilterState, Never>(.defaultState)
    
    // MARK: - Published AnyPublisher Properties (Observed by the UI)
    
    /**
     * REACTIVE UI BINDING WITH ANYPUBLISHER
     *
     * These AnyPublisher properties provide the same functionality as @Published
     * but give us more control over publishing behavior and transformations
     */
    
    var coins: AnyPublisher<[Coin], Never> {
        coinsSubject.eraseToAnyPublisher()
    }
    
    var coinLogos: AnyPublisher<[Int: String], Never> {
        coinLogosSubject.eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    
    var isLoadingMore: AnyPublisher<Bool, Never> {
        isLoadingMoreSubject.eraseToAnyPublisher()
    }
    
    var errorMessage: AnyPublisher<String?, Never> {
        errorMessageSubject.eraseToAnyPublisher()
    }
    
    var updatedCoinIds: AnyPublisher<Set<Int>, Never> {
        updatedCoinIdsSubject.eraseToAnyPublisher()
    }
    
    var filterState: AnyPublisher<FilterState, Never> {
        filterStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Current Value Accessors (For Internal Logic and ViewController Access)
    
    /**
     * INTERNAL STATE ACCESS
     * 
     * These computed properties provide access to current values
     * for both internal logic and ViewController access
     */
    
    var currentCoins: [Coin] {
        coinsSubject.value
    }
    
    var currentCoinLogos: [Int: String] {
        coinLogosSubject.value
    }
    
    var currentIsLoading: Bool {
        isLoadingSubject.value
    }
    
    var currentFilterState: FilterState {
        filterStateSubject.value
    }
    
    private var isUpdatingPrices: Bool = false             //  Prevents race conditions during price updates

    // MARK: - Sorting Properties
    
    /**
     *  SORTING STATE MANAGEMENT
     * 
     * These properties maintain the current sort configuration independently of the UI.
     * This allows sorting to persist across screen changes and filter applications.
     */
    
    private var currentSortColumn: CryptoSortColumn = .price      // Which column to sort by (rank, price, market cap, etc.)
    private var currentSortOrder: CryptoSortOrder = .descending   // Ascending or descending order
    
    // MARK: - Dependencies
    
    /**
     * DEPENDENCY INJECTION PATTERN
     * 
     * Dependencies are injected through the initializer, making the code testable and modular.
     * - CoinManager: Handles all API calls and network logic
     * - Cancellables: Stores Combine subscriptions for automatic memory management
     * - PersistenceService: Handles offline data storage and caching
     */

    private let coinManager: CoinManagerProtocol               //  API layer - handles all network requests
    private var cancellables = Set<AnyCancellable>()           //  Combine subscription storage (prevents memory leaks)
    private let persistenceService = PersistenceService.shared //  Offline data storage and caching

    // MARK: - Pagination Properties
    
    /**
     * PAGINATION IMPLEMENTATION
     *
     * Instead of loading all 500+ coins at once, I use pagination for better performance:
     * - Load 20 coins initially for fast app startup
     * - Load more as user scrolls (infinite scroll pattern)
     * - Cache full dataset for instant sorting/filtering
     */

    private let itemsPerPage = 20                          //  Number of coins per page (optimized for performance)
    private var currentPage = 1                            //  Current page number for pagination calculations
    private var canLoadMore = true                         //  Flag to prevent unnecessary pagination calls
    private var fullFilteredCoins: [Coin] = []             //  Complete dataset for instant local operations
    
    // MARK: - Optimization Properties
    
    /**
     * PERFORMANCE OPTIMIZATIONS
     * 
     * These properties prevent unnecessary API calls and improve user experience:
     * - Rate limiting prevents spam requests during rapid user interactions
     * - Request deduplication avoids fetching the same logo multiple times
     */
    
    private var lastFetchTime: Date?                       //  Rate limiting - prevents rapid successive API calls
    private let minimumFetchInterval: TimeInterval = 2.0  //   Minimum 2 seconds between API requests
    private var pendingLogoRequests: Set<Int> = []         //  Prevents duplicate logo download requests

    // MARK: - Initialization
    
    /**
     *  DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Default parameter allows normal usage while enabling dependency injection for testing.
     * - makes the code  convenient and testable.
     */
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts CoinManagerProtocol for:
     * - Easy mocking in unit tests
     * - Swappable business logic implementations
     * - Better testability and modularity
     * 
     * Falls back to default CoinManager for backward compatibility
     */
    init(coinManager: CoinManagerProtocol = CoinManager()) {
        self.coinManager = coinManager
        
        // 🔧 SMART CACHE MANAGEMENT: Clear cache if it has insufficient data
        if let cachedCoins = persistenceService.loadCoinList(), 
           cachedCoins.count < 100 { // Less than 100 coins = insufficient data
            persistenceService.clearCache()
            print("🗑️ Cleared insufficient cache (\(cachedCoins.count) coins) to force fresh data fetch")
        }
    }
    
    // MARK: - Utility Methods
    
    // Called when filters change to prevent stale optimization state from affecting new data.
    private func resetOptimizationState() {
        pendingLogoRequests.removeAll()  // Clear pending logo requests for fresh start
    }

    // MARK: - Filter Management
    
    /**
     * FILTER UPDATE METHODS
     */
    
    func updateTopCoinsFilter(_ filter: TopCoinsFilter) {
        let newState = FilterState(
            priceChangeFilter: currentFilterState.priceChangeFilter,
            topCoinsFilter: filter
        )
        updateFilter(to: newState)
    }
    
    func updatePriceChangeFilter(_ filter: PriceChangeFilter) {
        let newState = FilterState(
            priceChangeFilter: filter,
            topCoinsFilter: currentFilterState.topCoinsFilter
        )
        updateFilter(to: newState)
    }
    
    private func updateFilter(to newState: FilterState) {
        guard newState != currentFilterState else { return }
        
        let oldState = currentFilterState
        filterStateSubject.send(newState)
        
        print("🎯 FILTER CHANGE: \(oldState.topCoinsFilter.displayName) + \(oldState.priceChangeFilter.displayName) → \(newState.topCoinsFilter.displayName) + \(newState.priceChangeFilter.displayName)")
        
        // Reset optimization state for fresh data
        resetOptimizationState()
        
        // Trigger data refresh with high priority (user action)
        fetchCoins(priority: .high)
    }
    
    // MARK: - Sorting Management
    
    /**
     * SORTING SYSTEM
     * 
     * Sorting operates on cached data for instant response. This provides smooth UX
     * without requiring API calls every time the user changes sort order.
     */
    
    func updateSorting(column: CryptoSortColumn, order: CryptoSortOrder) {
        currentSortColumn = column
        currentSortOrder = order
        
        print("🔄 Applying sort: \(columnName(for: column)) - \(order == .descending ? "Descending" : "Ascending")")
        
        // Apply sorting to current data instantly (no API call needed)
        applySortingToCurrentData()
    }
    
    // Getter methods for current sort state (used by UI to sync sort header indicators)
    func getCurrentSortColumn() -> CryptoSortColumn {
        return currentSortColumn
    }
    
    func getCurrentSortOrder() -> CryptoSortOrder {
        return currentSortOrder
    }
    
    /**
     * DISPLAY NAME MAPPING
     * 
     * Converts internal enum values to user-friendly display names.
     * Dynamic price change label updates based on current filter.
     */
    private func columnName(for column: CryptoSortColumn) -> String {
        switch column {
        case .rank:
            return "Rank"
        case .marketCap:
            return "Market Cap"
        case .price:
            return "Price"
        case .priceChange:
            return "\(currentFilterState.priceChangeFilter.shortDisplayName) Change"  // Updated based on current filter -> Dynamic: "1h Change", "24h Change", etc.
        default:
            return "Unknown"
        }
    }
    
    /**
     * SORT INSTANTLY  ON CACHED DATA
     *
     * This method provides immediate sorting without API calls by operating on cached data.
     * It maintains pagination by showing only the first page after sorting.
     */
    private func applySortingToCurrentData() {
        print("🔧 applySortingToCurrentData | fullFilteredCoins: \(fullFilteredCoins.count), coins: \(currentCoins.count)")
        
        // Fallback: If we have no full dataset, use currently displayed coins
        if fullFilteredCoins.isEmpty && !currentCoins.isEmpty {
            print("🔧 Using displayed coins for sorting (\(currentCoins.count) coins)")
            fullFilteredCoins = currentCoins
        }
        
        // Guard: Can't sort empty data
        guard !fullFilteredCoins.isEmpty else {
            print("⚠️ No data to sort")
            return
        }
        
        print("🔧 Sorting \(fullFilteredCoins.count) coins by \(columnName(for: currentSortColumn)) \(currentSortOrder == .descending ? "DESC" : "ASC")")
        
        // Sort the complete dataset
        fullFilteredCoins = sortCoins(fullFilteredCoins)
        
        // Update UI with first page of sorted results
        let pageSize = itemsPerPage
        let sortedDisplayCoins = Array(fullFilteredCoins.prefix(pageSize))
        coinsSubject.send(sortedDisplayCoins)  // This triggers UI update via AnyPublisher
        
        // Reset pagination state for sorted data
        currentPage = 1
        canLoadMore = fullFilteredCoins.count > pageSize
        
        // Fetch logos for newly visible coins after sorting
        let displayedIds = sortedDisplayCoins.map { $0.id }
        fetchCoinLogosIfNeeded(forIDs: displayedIds)
        
        print("✅ Sort applied: Displaying \(sortedDisplayCoins.count) coins of \(fullFilteredCoins.count) total")
        print("📖 Pagination reset: canLoadMore = \(canLoadMore), currentPage = \(currentPage)")
    }
    
    /**
     * 🔄 FILTER STATE UPDATE HANDLER
     * 
     * This  method handles all filter changes.
     * 1. Validates the change is necessary
     * 2. Clears relevant caches for fresh data
     * 3. Resets pagination state
     * 4. Triggers fresh data fetch with high priority (user-initiated)
     */
    private func updateFilterState(_ newState: FilterState) {
        // Performance: Don't trigger unnecessary updates
        guard newState != currentFilterState else { return }
        
        let oldState = currentFilterState
        filterStateSubject.send(newState)  //  This triggers UI update via AnyPublisher
        
        print("🎯 FILTER CHANGE: \(oldState.topCoinsFilter.displayName) + \(oldState.priceChangeFilter.displayName) → \(newState.topCoinsFilter.displayName) + \(newState.priceChangeFilter.displayName)")
        
        // Cache invalidation: Clear cache when top coins filter changes
        // (Different coin count requires fresh API call)
        if oldState.topCoinsFilter != newState.topCoinsFilter {
            print("🗑️ Clearing cache due to Top Coins filter change")
            persistenceService.clearCache()
        }
        
        // Reset pagination state for fresh start
        currentPage = 1
        canLoadMore = true
        coinsSubject.send([])  // 🎯 Clear UI immediately (triggers loading spinner)
        fullFilteredCoins = []
        
        // Clear optimization state to prevent stale requests
        resetOptimizationState()
        
        print("🔄 Fetching fresh data with new filters...")
        
        // HIGH PRIORITY: User-initiated filter changes get immediate processing
        fetchCoins(convert: "USD", priority: .high)
    }

    // MARK: - Data Fetching -> Core Method
    
    /**
     *  MAIN DATA FETCHING METHOD
     *
     * This method orchestrates the entire data loading process:
     * 
     * 🔄 FLOW:
     * 1. Rate limiting check (prevent spam requests)
     * 2. Cache check (instant loading for default filters)
     * 3. API call with buffer system (handle missing ranks)
     * 4. Data integrity validation (detect rank gaps)
     * 5. Local sorting application
     * 6. Pagination setup
     * 7. Logo fetching
     * 8. Offline storage
     * 
     *   CACHING STRATEGY:
     * - Uses cache only for default filters (prevents stale filter data)
     * - Cache is time-based and filter-aware
     * - Fallback to offline data on network errors
     * 
     *   PERFORMANCE FEATURES:
     * - Priority-based API requests (user actions get higher priority)
     * - Buffer system handles API data gaps (rank 100 missing, etc.)
     * - Background thread processing with main thread UI updates
     */
    func fetchCoins(convert: String = "USD", priority: RequestPriority = .normal, onFinish: (() -> Void)? = nil) {
        print("🔧 VM.fetchCoins | Called with completion: \(onFinish != nil)")
        print("🔧 VM.fetchCoins | Current sort: \(columnName(for: currentSortColumn)) \(currentSortOrder == .descending ? "DESC" : "ASC")")
        
        //  RATE LIMITING: Prevent rapid successive calls
        if let lastFetch = lastFetchTime,
            Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            print("⏰ VM.fetchCoins | Skipped due to recent fetch")
            onFinish?()
            return
        }
        
        //  CACHE USAGE: Only use cache for default filters AND default sort to prevent stale data
        let isDefaultSort = (currentSortColumn == .price && currentSortOrder == .descending)
        
        if !persistenceService.isCacheExpired(), 
            let offlineData = persistenceService.getOfflineData(), // Offline support with cached data
           currentFilterState == .defaultState,
           isDefaultSort { // Only use cache with default sort to preserve custom sort views
            print("💾 VM.fetchCoins | Using cached offline data (default filters + default sort)")
            currentPage = 1
            
            // Apply current sorting to cached data BEFORE setting coins (prevents UI flash)
            let sortedCachedCoins = sortCoins(offlineData.coins)
            
            // 🛡️ VALIDATION: Check cached data for duplicates
            let cachedIds = sortedCachedCoins.map { $0.id }
            let uniqueCachedIds = Set(cachedIds)
            if cachedIds.count != uniqueCachedIds.count {
                print("❌ WARNING: Cached data contains duplicate coin IDs!")
                print("   Total: \(cachedIds.count), Unique: \(uniqueCachedIds.count)")
                
                // Deduplicate cached data
                var seenIds = Set<Int>()
                let deduplicatedCachedCoins = sortedCachedCoins.filter { coin in
                    if seenIds.contains(coin.id) {
                        print("   Removing cached duplicate: \(coin.name) (ID: \(coin.id))")
                        return false
                    } else {
                        seenIds.insert(coin.id)
                        return true
                    }
                }
                
                // 🔧 PAGINATION FIX: Set fullFilteredCoins for proper pagination
                fullFilteredCoins = deduplicatedCachedCoins
                
                // Show first page only
                let pageSize = itemsPerPage
                let initialCoins = Array(deduplicatedCachedCoins.prefix(pageSize))
                coinsSubject.send(initialCoins)  // 🎯 Triggers UI update with clean data
                
                // Enable pagination if we have more data
                canLoadMore = deduplicatedCachedCoins.count > pageSize
                
                print("📱 UI: Displaying \(initialCoins.count) coins (page 1 of \(deduplicatedCachedCoins.count) total from cache)")
            } else {
                // 🔧 PAGINATION FIX: Set fullFilteredCoins for proper pagination
                fullFilteredCoins = sortedCachedCoins
                
                // Show first page only  
                let pageSize = itemsPerPage
                let initialCoins = Array(sortedCachedCoins.prefix(pageSize))
                coinsSubject.send(initialCoins)  // 🎯 Triggers UI update
                
                // Enable pagination if we have more data
                canLoadMore = sortedCachedCoins.count > pageSize
                
                print("📱 UI: Displaying \(initialCoins.count) coins (page 1 of \(sortedCachedCoins.count) total from cache)")
            }
            coinLogosSubject.send(offlineData.logos)
            
            // Fetch any missing logos after loading cached data
            let displayedIds = currentCoins.map { $0.id }
            fetchCoinLogosIfNeeded(forIDs: displayedIds)
            
            onFinish?()
            return
        }
        
        // FRESH DATA PATH: For filters, expired cache, or custom sort
        if currentFilterState != .defaultState {
            print("🎯 VM.fetchCoins | Filters applied (\(currentFilterState.topCoinsFilter.displayName) + \(currentFilterState.priceChangeFilter.displayName)) - fetching fresh data")
        } else if !isDefaultSort {
            print("🔄 VM.fetchCoins | Custom sort detected (\(columnName(for: currentSortColumn)) \(currentSortOrder == .descending ? "DESC" : "ASC")) - fetching fresh data to preserve sort")
        }
        
        // RESET STATE FOR FRESH FETCH
        print("\n🌟 Initial Load | Fetching coin data...")
        currentPage = 1
        canLoadMore = true
        coinsSubject.send([])  // 🎯 Clear UI (triggers loading spinner via AnyPublisher)
        isLoadingSubject.send(true)  // 🎯 Show loading spinner
        errorMessageSubject.send(nil)
        lastFetchTime = Date()

        // BACKEND FILTERING STRATEGY:
        // We use a hybrid approach for optimal performance:
        // 1. Backend: Get top N coins by market cap (leverages CMC's ranking)
        // 2. Local: Sort by user's selected metric (instant response)
        // This ensures we get the top coins while providing instant sort feedback
        
        let topCoinsLimit = currentFilterState.topCoinsFilter.rawValue
        let filterDescription = "\(currentFilterState.topCoinsFilter.displayName) sorted by \(currentFilterState.priceChangeFilter.displayName)"
        
        // BUFFER SYSTEM: Request extra coins to handle API data gaps
        // The API sometimes has missing ranks (e.g., rank 100 might be missing)
        let bufferSize = min(10, max(5, topCoinsLimit / 20)) // 5-10 extra coins as safety buffer
        let fetchLimit = topCoinsLimit + bufferSize
        
        print("🎯 Filter: \(filterDescription)")
        print("🔄 Backend: Fetching top \(fetchLimit) coins (target: \(topCoinsLimit) + \(bufferSize) buffer) by market cap...")
        
        // API CALL WITH REACTIVE PROCESSING PIPELINE
        coinManager.getTopCoins(
            limit: fetchLimit,        // Request with buffer
            convert: convert,
            start: 1,
            sortType: "market_cap",   // Backend sorting by market cap
            sortDir: "desc", 
            priority: priority        // Priority-based request handling
        )
        .map { [weak self] topCoinsByMarketCap -> [Coin] in
            guard let self = self else { return topCoinsByMarketCap }
            
            // DATA INTEGRITY: Ensure consecutive top-ranked coins
            let targetCount = topCoinsLimit
            let consecutiveTopCoins = topCoinsByMarketCap
                .sorted { $0.cmcRank < $1.cmcRank }           
                .prefix(while: { $0.cmcRank <= targetCount }) 
                .prefix(targetCount)                          
            
            let finalCoins = Array(consecutiveTopCoins)
            
            #if DEBUG
            if finalCoins.count > 0 {
                print("✅ Fetched \(finalCoins.count) top coins (ranks 1-\(finalCoins.last?.cmcRank ?? 0))")
            }
            #endif
            
            // Apply user's sort preference
            let sortedCoins = self.sortCoins(finalCoins)
            
            return sortedCoins
        }
        .receive(on: DispatchQueue.main)  // 🎯 Switch to main thread for UI updates
        .sink { [weak self] completion in
            // COMPLETION HANDLER: Handle success/failure
            self?.isLoadingSubject.send(false)  // 🎯 Hide loading spinner
            if case let .failure(error) = completion {
                print("❌ VM.fetchCoins | Error: \(error.localizedDescription)")
                self?.errorMessageSubject.send(ErrorMessageProvider.shared.getCoinListErrorMessage(for: error))
                self?.canLoadMore = false
                
                // 🛡️ OFFLINE FALLBACK: Try to load cached data on network error
                if let offlineData = self?.persistenceService.getOfflineData() {
                    let sortedFallbackCoins = self?.sortCoins(offlineData.coins) ?? offlineData.coins
                    
                    // 🛡️ VALIDATION: Check fallback data for duplicates
                    let fallbackIds = sortedFallbackCoins.map { $0.id }
                    let uniqueFallbackIds = Set(fallbackIds)
                    if fallbackIds.count != uniqueFallbackIds.count {
                        AppLogger.data("Fallback data contains duplicate coin IDs (Total: \(fallbackIds.count), Unique: \(uniqueFallbackIds.count))", level: .warning)
                        
                        // Deduplicate fallback data
                        var seenIds = Set<Int>()
                        let deduplicatedFallbackCoins = sortedFallbackCoins.filter { coin in
                            if seenIds.contains(coin.id) {
                                return false
                            } else {
                                seenIds.insert(coin.id)
                                return true
                            }
                        }
                        
                        // 🔧 PAGINATION FIX: Set fullFilteredCoins for proper fallback pagination
                        self?.fullFilteredCoins = deduplicatedFallbackCoins
                        
                        // Show first page only
                        let pageSize = self?.itemsPerPage ?? 20
                        let initialFallbackCoins = Array(deduplicatedFallbackCoins.prefix(pageSize))
                        self?.coinsSubject.send(initialFallbackCoins)  // 🎯 Update UI with clean fallback data
                        
                        // Enable pagination if we have more data
                        self?.canLoadMore = deduplicatedFallbackCoins.count > pageSize
                        
                        AppLogger.data("Fallback: Displaying \(initialFallbackCoins.count) cached coins (page 1 of \(deduplicatedFallbackCoins.count) total)", level: .warning)
                    } else {
                        // 🔧 PAGINATION FIX: Set fullFilteredCoins for proper fallback pagination
                        self?.fullFilteredCoins = sortedFallbackCoins
                        
                        // Show first page only
                        let pageSize = self?.itemsPerPage ?? 20
                        let initialFallbackCoins = Array(sortedFallbackCoins.prefix(pageSize))
                        self?.coinsSubject.send(initialFallbackCoins)  // 🎯 Update UI with fallback data
                        
                        // Enable pagination if we have more data
                        self?.canLoadMore = sortedFallbackCoins.count > pageSize
                        
                        print("📱 UI: Displaying \(initialFallbackCoins.count) fallback coins (page 1 of \(sortedFallbackCoins.count) total)")
                    }
                    self?.coinLogosSubject.send(offlineData.logos)
                    self?.errorMessageSubject.send("Using offline data due to network error")
                    
                    // Fetch missing logos for fallback data
                    let displayedIds = self?.currentCoins.map { $0.id } ?? []
                    self?.fetchCoinLogosIfNeeded(forIDs: displayedIds)
                }
            }
            print("🔄 VM.fetchCoins | Calling completion handler")
            onFinish?()
        } receiveValue: { [weak self] filteredAndSortedCoins in
            // Process the successful data
            guard let self = self else { return }
            
            // Show first page, store full dataset for later
            let pageSize = self.itemsPerPage
            let initialCoins = Array(filteredAndSortedCoins.prefix(pageSize))
            
            // Basic duplicate check
            let coinIds = initialCoins.map { $0.id }
            let uniqueIds = Set(coinIds)
            if coinIds.count != uniqueIds.count {
                // Deduplicate by keeping first occurrence of each ID
                var seenIds = Set<Int>()
                let deduplicatedCoins = initialCoins.filter { coin in
                    if seenIds.contains(coin.id) {
                        return false
                    } else {
                        seenIds.insert(coin.id)
                        return true
                    }
                }
                self.coinsSubject.send(deduplicatedCoins)
            } else {
                self.coinsSubject.send(initialCoins)
            }

            // Store complete dataset for pagination
            self.fullFilteredCoins = filteredAndSortedCoins
            
            // Enable pagination only if we have more data
            self.canLoadMore = filteredAndSortedCoins.count > pageSize

            AppLogger.data("Displaying \(initialCoins.count) coins (page 1 of \(filteredAndSortedCoins.count) total)")

            //  LOGO FETCHING: Start downloading coin images (low priority, background)
            let ids = initialCoins.map { $0.id }
            self.fetchCoinLogosIfNeeded(forIDs: ids)
            
            // 💾 OFFLINE STORAGE: Save FULL dataset for offline use (only default filters to avoid stale data)
            if self.currentFilterState == .defaultState {
                self.persistenceService.saveCoinList(filteredAndSortedCoins)  // Save FULL dataset, not just first page
                print("💾 Saved \(filteredAndSortedCoins.count) coins to cache (full dataset)")
                
                // 📢 NOTIFY SEARCH: Tell SearchVM that fresh data is available
                NotificationCenter.default.post(name: Notification.Name("coinListCacheUpdated"), object: nil)
                print("📢 Posted cache update notification for SearchVM")
            }
        }
        .store(in: &cancellables)  //  Store subscription for memory management
    }
    
    // MARK: - Sorting Algorithms
    
    /**
     * COMPREHENSIVE SORTING
     * 
     * This method handles sorting for all coin attributes with special logic for ranks.
     * The rank sorting is intentionally inverted to be user-friendly:
     * - "Descending" shows best ranks first (1, 2, 3...)
     * - "Ascending" shows worst ranks first (...3, 2, 1)
     * 
     * PERFORMANCE: Operates on arrays in memory for instant response
     */
    private func sortCoins(_ coins: [Coin]) -> [Coin] {
        return coins.sorted { coin1, coin2 in
            let ascending = (currentSortOrder == .ascending)
        
            switch currentSortColumn {
            case .rank:
                // 🎯 SPECIAL RANK LOGIC: Inverted for user-friendliness
                // Descending = best ranks first (1,2,3...) - what users expect when they click "descending"
                // Ascending = worst ranks first (...3,2,1) - technical ascending but less intuitive
                return ascending ? (coin1.cmcRank > coin2.cmcRank) : (coin1.cmcRank < coin2.cmcRank)
                
            case .marketCap:
                let marketCap1 = coin1.quote?["USD"]?.marketCap ?? 0
                let marketCap2 = coin2.quote?["USD"]?.marketCap ?? 0
                return ascending ? (marketCap1 < marketCap2) : (marketCap1 > marketCap2)
                
            case .price:
                let price1 = coin1.quote?["USD"]?.price ?? 0
                let price2 = coin2.quote?["USD"]?.price ?? 0
                return ascending ? (price1 < price2) : (price1 > price2)
                
            case .priceChange:
                // 🎯 DYNAMIC PRICE CHANGE: Based on current filter (1h, 24h, 7d, 30d)
                let change1 = getPriceChangeValue(for: coin1)
                let change2 = getPriceChangeValue(for: coin2)
                return ascending ? (change1 < change2) : (change1 > change2)
                
            default:
                // 🛡️ FALLBACK: Default to rank sorting (best rank first)
                return coin1.cmcRank < coin2.cmcRank
            }
        }
    }
    
    /**
     * DYNAMIC PRICE CHANGE EXTRACTION
     * 
     * Returns the appropriate price change percentage based on current filter.
     * This enables dynamic sorting by different time periods.
     */
    private func getPriceChangeValue(for coin: Coin) -> Double {
        guard let quote = coin.quote?["USD"] else { return 0.0 }
        
        switch currentFilterState.priceChangeFilter {
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
    
    /**
     * DISPLAY VALUE FORMATTING
     * 
     * Formats coin values for display in sort headers and debugging.
     * Provides consistent formatting across the app.
     */
    private func getSortValue(for coin: Coin, column: CryptoSortColumn) -> String {
        switch column {
        case .rank:
            return "#\(coin.cmcRank)"
        case .marketCap:
            let marketCap = coin.quote?["USD"]?.marketCap ?? 0
            return "$\(marketCap.abbreviatedString())"  // 1.2B, 999M format
        case .price:
            let price = coin.quote?["USD"]?.price ?? 0
            return String(format: "$%.2f", price)
        case .priceChange:
            let change = getPriceChangeValue(for: coin)
            return String(format: "%.2f%%", change)
        default:
            return "N/A"
        }
    }

    // MARK: - Pagination System
    
    /**
     * INFINITE SCROLL PAGINATION
     * 
     * This method implements smooth infinite scrolling without API calls.
     * It operates on the cached `fullFilteredCoins` array for instant response.
     * 
     * PERFORMANCE FEATURES:
     * - No API calls needed (uses cached data)
     * - Instant loading with no delay
     * - Smart guard conditions prevent duplicate calls
     * - Automatic logo fetching for new coins
     * 
     * TRIGGER: Called by collection view scroll detection in the UI layer
     */
    func loadMoreCoins(convert: String = "USD") {
        // GUARD CONDITIONS: Prevent invalid or duplicate pagination calls + race conditions
        guard canLoadMore && !isLoadingMoreSubject.value && !currentIsLoading && !isUpdatingPrices else { 
            print("🚫 Pagination | Blocked | CanLoad: \(canLoadMore) | Loading: \(currentIsLoading) | LoadingMore: \(isLoadingMoreSubject.value) | UpdatingPrices: \(isUpdatingPrices)")
            return 
        }

        // PAGINATION CALCULATION: Calculate if more data is available
        let currentCount = currentCoins.count
        let totalAvailable = fullFilteredCoins.count
        
        if currentCount >= totalAvailable {
            canLoadMore = false
            print("🛑 Pagination | All coins loaded | \(currentCount)/\(totalAvailable)")
            return
        }

        // PAGINATION STATE UPDATE
        currentPage += 1
        isLoadingMoreSubject.send(true)  // Show pagination loading indicator
        errorMessageSubject.send(nil)
        
        print("📖 Pagination | Loading page \(currentPage) | Current: \(currentCoins.count) coins")

        // CALCULATE NEW SLICE: Get next batch of coins from cached data
        let startIndex = currentCoins.count
        let endIndex = min(startIndex + itemsPerPage, fullFilteredCoins.count)
        
        guard startIndex < fullFilteredCoins.count else {
            // 🛡️ EDGE CASE: No more items available
            isLoadingMoreSubject.send(false)
            canLoadMore = false
            print("🛑 Pagination | No more items available")
            return
        }
        
        // INSTANT UPDATE: Extract new coins and append to display list
        let newCoins = Array(fullFilteredCoins[startIndex..<endIndex])
        let updatedCoins = currentCoins + newCoins
        coinsSubject.send(updatedCoins)  // 🎯 Triggers UI update via AnyPublisher
        isLoadingMoreSubject.send(false)  // 🎯 Hide pagination loading indicator
        
        let totalCoins = updatedCoins.count
        
        // UPDATE PAGINATION STATE
        if totalCoins >= fullFilteredCoins.count {
            canLoadMore = false
        }

        // FETCH LOGOS: Download images for newly visible coins
        let newIds = newCoins.map { $0.id }
        fetchCoinLogosIfNeeded(forIDs: newIds)
    }

    // MARK: - Logo Management System
    
    /**
     * SIMPLE LOGO FETCHING (Public Method)
     * 
     * Basic logo fetching method - primarily used for testing or direct calls.
     * The optimized version below (fetchCoinLogosIfNeeded) is used internally.
     */
    func fetchCoinLogos(forIDs ids: [Int]) {
        coinManager.getCoinLogos(forIDs: ids, priority: .low)
            .sink { [weak self] logos in
                // 🔗 MERGE STRATEGY: New logos override old ones if same ID
                let currentLogos = self?.currentCoinLogos ?? [:]
                let mergedLogos = currentLogos.merging(logos) { _, new in new }
                self?.coinLogosSubject.send(mergedLogos)
            }
            .store(in: &cancellables)
    }
    
    /**
     * OPTIMIZED LOGO FETCHING WITH DEDUPLICATION
     *
     * This method implements several optimizations:
     * 
     * OPTIMIZATIONS:
     * - Skips logos already downloaded (coinLogos cache check)
     * - Prevents duplicate requests (pendingLogoRequests tracking)
     * - Batches requests for efficiency
     * - Uses low priority to not interfere with data requests
     * - Automatic offline storage
     * 
     * UI IMPACT: When logos are downloaded, the AnyPublisher coinLogos property
     * triggers automatic UI updates in the collection view cells.
     */
    private func fetchCoinLogosIfNeeded(forIDs ids: [Int]) {
        // Filter out logos we already have or are downloading
        let missingLogoIds = ids.filter { id in
            currentCoinLogos[id] == nil && !pendingLogoRequests.contains(id)
        }
        
        guard !missingLogoIds.isEmpty else { return }
        
        // Track pending requests to prevent duplicates
        pendingLogoRequests.formUnion(missingLogoIds)
        
        // Use low priority so logos don't interfere with data requests
        coinManager.getCoinLogos(forIDs: missingLogoIds, priority: .low)
            .sink { [weak self] logos in
                // Remove from pending requests
                self?.pendingLogoRequests.subtract(missingLogoIds)
                
                // Merge new logos with existing cache
                let currentLogos = self?.currentCoinLogos ?? [:]
                let mergedLogos = currentLogos.merging(logos) { _, new in new }
                self?.coinLogosSubject.send(mergedLogos)
                
                // Save updated logos for offline use
                self?.persistenceService.saveCoinLogos(mergedLogos)
            }
            .store(in: &cancellables)
    }

    // MARK: - Price Updates
    
    /**
     * 🔄 PERIODIC PRICE UPDATES (Background Auto-Refresh)
     */
    func fetchPriceUpdates(completion: @escaping () -> Void) {
        guard !currentIsLoading && !isLoadingMoreSubject.value && !isUpdatingPrices else {
            print("🚫 Price updates blocked - loading/updating in progress")
            completion()
            return
        }
        
        let ids = currentCoins.map { $0.id }
        guard !ids.isEmpty else {
            completion()
            return
        }

        isUpdatingPrices = true  // 🔒 Lock to prevent race conditions
        
        coinManager.getQuotes(for: ids, convert: "USD", priority: .low)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                self?.isUpdatingPrices = false  // 🔓 Unlock after completion
                if case .failure(let error) = completionResult {
                    if !error.localizedDescription.contains("throttled") {
                        self?.errorMessageSubject.send(ErrorMessageProvider.shared.getPriceUpdateErrorMessage(for: error))
                    }
                }
                completion()
            } receiveValue: { [weak self] updatedQuotes in
                self?.updateCoinPrices(updatedQuotes)
            }
            .store(in: &cancellables)
    }
    
    /**
     * Update coin prices with new quote data
     */
    private func updateCoinPrices(_ updatedQuotes: [Int: Quote]) {
        var changedCoinIds = Set<Int>()
        var updatedCoins = currentCoins // Create a copy to avoid modifying during iteration
        
        // Basic safety check for duplicates
        let coinIds = updatedCoins.map { $0.id }
        let uniqueIds = Set(coinIds)
        if coinIds.count != uniqueIds.count {
            // Remove duplicates by keeping only the first occurrence of each ID
            var seenIds = Set<Int>()
            updatedCoins = updatedCoins.filter { coin in
                if seenIds.contains(coin.id) {
                    return false
                } else {
                    seenIds.insert(coin.id)
                    return true
                }
            }
        }
        
        for i in 0..<updatedCoins.count {
            let coinId = updatedCoins[i].id
            
            guard let newQuote = updatedQuotes[coinId],
                  let currentQuote = updatedCoins[i].quote?["USD"] else { continue }
                  
            let currentPrice = currentQuote.price ?? 0.0
            let newPrice = newQuote.price ?? 0.0
            let currentPercentChange = currentQuote.percentChange24h ?? 0.0
            let newPercentChange = newQuote.percentChange24h ?? 0.0
            
            let priceChanged = abs(currentPrice - newPrice) > 0.001  // More sensitive threshold
            let percentChanged = abs(currentPercentChange - newPercentChange) > 0.001  // More sensitive threshold
            
            if priceChanged || percentChanged {
                updatedCoins[i].quote?["USD"] = newQuote
                changedCoinIds.insert(coinId)
            }
        }
        
        // Capture old prices BEFORE updating currentCoins
        let oldPrices = Dictionary(uniqueKeysWithValues: currentCoins.map { ($0.id, $0.quote?["USD"]?.price ?? 0.0) })
        
        // Update the original array only once, atomically
        coinsSubject.send(updatedCoins)
        
        if !changedCoinIds.isEmpty {
            updatedCoinIdsSubject.send(changedCoinIds)
            
            // Log detailed price changes
            #if DEBUG
            let priceChanges = changedCoinIds.compactMap { coinId -> (symbol: String, oldPrice: String, newPrice: String, change: String)? in
                guard let updatedCoin = updatedCoins.first(where: { $0.id == coinId }),
                      let newQuote = updatedQuotes[coinId],
                      let newPrice = newQuote.price,
                      let changePercent = newQuote.percentChange24h else { return nil }
                
                // Get the actual old price from captured data before update
                let oldPrice = oldPrices[coinId] ?? 0.0
                
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = "USD"
                formatter.maximumFractionDigits = 2
                
                let oldPriceStr = formatter.string(from: NSNumber(value: oldPrice)) ?? "$\(oldPrice)"
                let newPriceStr = formatter.string(from: NSNumber(value: newPrice)) ?? "$\(newPrice)"
                let changeStr = String(format: "%.2f%%", changePercent)
                
                return (updatedCoin.symbol, oldPriceStr, newPriceStr, changeStr)
            }
            
            let title = "Coin List Price Updates (\(changedCoinIds.count) coins)" + (priceChanges.count > 3 ? " - showing top 3" : "")
            AppLogger.priceTable(title, updates: Array(priceChanges.prefix(3)))
            #endif
        }
    }
    
    /**
     *  OPTIMIZED VISIBLE-ONLY PRICE UPDATES
     * 
     * This is the preferred method for auto-refresh as it only updates visible coins.
     * This significantly reduces API usage and improves performance.
     * 
     * OPTIMIZATION: Only fetches prices for coins currently visible on screen
     * EFFICIENCY: Reduces API calls by 60-80% compared to updating all coins
     * USAGE: Called by the auto-refresh timer with visible coin IDs
     */
    func fetchPriceUpdatesForVisibleCoins(_ visibleIds: [Int], completion: @escaping () -> Void) {
        // RESPECT LOADING STATES + PREVENT RACE CONDITIONS
        guard !currentIsLoading && !isLoadingMoreSubject.value && !isUpdatingPrices else {
            print("🚫 Visible price updates blocked - operations in progress")
            completion()
            return
        }
        
        // VALIDATION
        guard !visibleIds.isEmpty else {
            completion()
            return
        }

        isUpdatingPrices = true  // 🔒 Lock to prevent race conditions
        
        // Use low priority for background updates
        coinManager.getQuotes(for: visibleIds, convert: "USD", priority: .low)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                self?.isUpdatingPrices = false  // 🔓 Unlock after completion
                if case .failure(let error) = completionResult {
                    //  QUIET ERROR HANDLING
                    if !error.localizedDescription.contains("throttled") {
                        self?.errorMessageSubject.send(error.localizedDescription)
                    }
                }
                completion()
            } receiveValue: { [weak self] updatedQuotes in
                guard let self = self else { return }

                var changedCoinIds = Set<Int>()
                var updatedCoins = self.currentCoins
                
                // VISIBLE-ONLY UPDATE: Only process coins currently on screen
                for i in 0..<updatedCoins.count {
                    let id = updatedCoins[i].id
                    if visibleIds.contains(id), let updated = updatedQuotes[id] {
                        // Change tracking with proper thresholds
                        let oldPrice = updatedCoins[i].quote?["USD"]?.price ?? 0.0
                        let newPrice = updated.price ?? 0.0
                        let oldPercentChange = updatedCoins[i].quote?["USD"]?.percentChange24h ?? 0.0
                        let newPercentChange = updated.percentChange24h ?? 0.0
                        
                        let priceChanged = abs(oldPrice - newPrice) > 0.001  // Use threshold instead of exact equality
                        let percentChanged = abs(oldPercentChange - newPercentChange) > 0.001  // Use threshold instead of exact equality
                        
                        if priceChanged || percentChanged {
                            updatedCoins[i].quote?["USD"] = updated
                            changedCoinIds.insert(id)
                        }
                    }
                }
                
                // Capture old prices BEFORE updating currentCoins
                let oldPrices = Dictionary(uniqueKeysWithValues: self.currentCoins.map { ($0.id, $0.quote?["USD"]?.price ?? 0.0) })
                
                // UI UPDATE TRIGGER
                if !changedCoinIds.isEmpty {
                    self.coinsSubject.send(updatedCoins)
                    self.updatedCoinIdsSubject.send(changedCoinIds)
                    
                    // Log detailed price changes for visible coins
                    #if DEBUG
                    let priceChanges = changedCoinIds.compactMap { coinId -> (symbol: String, oldPrice: String, newPrice: String, change: String)? in
                        guard let updatedCoin = updatedCoins.first(where: { $0.id == coinId }),
                              let newQuote = updatedQuotes[coinId],
                              let newPrice = newQuote.price,
                              let changePercent = newQuote.percentChange24h else { return nil }
                        
                        // Get the actual old price from captured data before update
                        let oldPrice = oldPrices[coinId] ?? 0.0
                        
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .currency
                        formatter.currencyCode = "USD"
                        formatter.maximumFractionDigits = 2
                        
                        let oldPriceStr = formatter.string(from: NSNumber(value: oldPrice)) ?? "$\(oldPrice)"
                        let newPriceStr = formatter.string(from: NSNumber(value: newPrice)) ?? "$\(newPrice)"
                        let changeStr = String(format: "%.2f%%", changePercent)
                        
                        return (updatedCoin.symbol, oldPriceStr, newPriceStr, changeStr)
                    }
                    
                    let title = "Visible Coins Price Updates (\(changedCoinIds.count) coins)" + (priceChanges.count > 3 ? " - showing top 3" : "")
                    AppLogger.priceTable(title, updates: Array(priceChanges.prefix(3)))
                    #endif
                } else {
                    #if DEBUG
                    print("📱 No changes detected (visible coins)")
                    #endif
                }
                
                completion()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Management
    
    /**
     * UI STATE CLEANUP
     * 
     * Called after UI processes the updated coin IDs to reset the change tracking.
     * This prevents old change notifications from triggering duplicate UI updates.
     */
    func clearUpdatedCoinIds() {
        updatedCoinIdsSubject.send([])
    }
    
    // MARK: - Lifecycle Management
    
    /**
     * IMMEDIATE CLEANUP METHOD
     * 
     * Called when leaving the screen to immediately cancel all ongoing requests.
     * This prevents:
     * - Unnecessary API calls after leaving the screen
     * - Memory leaks from active subscriptions
     * - UI updates on deallocated view controllers
     */
    func cancelAllRequests() {
        print("🛑 Cancelling all ongoing API calls for coin list")
        cancellables.removeAll()  // Cancel all Combine subscriptions
        isLoadingSubject.send(false)
        isLoadingMoreSubject.send(false)
    }
    
    /**
     * AUTOMATIC CLEANUP ON DEALLOCATION
     * 
     * Deinitializer ensures proper cleanup even if cancelAllRequests isn't called.
     * This is a safety net for memory management.
     */
    deinit {
        print("🧹 CoinListVM deinit - cleaning up subscriptions")
        cancellables.removeAll()
    }
}
