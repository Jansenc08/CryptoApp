import Foundation
import Combine
import CoreData

final class WatchlistVM: ObservableObject {
    
    // MARK: - Private Subjects (Internal State Management)
    
    /**
     * REACTIVE STATE MANAGEMENT WITH SUBJECTS
     * 
     * Using CurrentValueSubject for state that needs current values
     * This gives us more control over when and how values are published
     */
    
    private let watchlistCoinsSubject = CurrentValueSubject<[Coin], Never>([])
    private let coinLogosSubject = CurrentValueSubject<[Int: String], Never>([:])
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = CurrentValueSubject<String?, Never>(nil)
    private let updatedCoinIdsSubject = CurrentValueSubject<Set<Int>, Never>([])
    
    // MARK: - Published AnyPublisher Properties
    
    /**
     * REACTIVE UI BINDING WITH ANYPUBLISHER
     * 
     * These AnyPublisher properties provide the same functionality as @Published
     * but give us more control over publishing behavior and transformations
     */
    
    var watchlistCoins: AnyPublisher<[Coin], Never> {
        watchlistCoinsSubject.eraseToAnyPublisher()
    }
    
    var coinLogos: AnyPublisher<[Int: String], Never> {
        coinLogosSubject.eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    
    var errorMessage: AnyPublisher<String?, Never> {
        errorMessageSubject.eraseToAnyPublisher()
    }
    
    var updatedCoinIds: AnyPublisher<Set<Int>, Never> {
        updatedCoinIdsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Current Value Accessors (For Internal Logic and ViewController Access)
    
    /**
     * INTERNAL STATE ACCESS
     * 
     * These computed properties provide access to current values
     * for both internal logic and ViewController access
     */
    
    var currentWatchlistCoins: [Coin] {
        watchlistCoinsSubject.value
    }
    
    var currentCoinLogos: [Int: String] {
        coinLogosSubject.value
    }
    
    var currentIsLoading: Bool {
        isLoadingSubject.value
    }
    
    // MARK: - Sorting Properties
    
    /**
     * WATCHLIST SORTING STATE MANAGEMENT
     * 
     * These properties maintain the current sort configuration for the watchlist.
     * Default sort is by descending rank (best ranked coins first).
     */
    
    private var currentSortColumn: CryptoSortColumn = .rank          // Default to rank column
    private var currentSortOrder: CryptoSortOrder = .descending     // Default to descending (best ranks first)
    
    // MARK: - Dependencies
    
    private let watchlistManager = WatchlistManager.shared
    private let coinManager: CoinManager
    private var cancellables = Set<AnyCancellable>()
    private var requestCancellables = Set<AnyCancellable>()  // Separate for API requests
    private var updateTimer: Timer?
    
    // MARK: - Optimization Properties
    
    /**
     * PERFORMANCE OPTIMIZATIONS FOR WATCHLIST VM
     * 
     * Efficient Data Flow:
     * - Eliminates redundant loadWatchlistCoins() calls
     * - Uses optimized watchlist manager's O(1) lookups
     * - Debounced price updates to prevent API spam
     * -  Change detection to minimize UI updates
     *
     * Background Processing:
     * - Price updates on background queue
     * - Logo fetching optimized with local caching
     * - Non-blocking operations for smooth UI
     */
    
    private var lastPriceUpdate: Date = Date()
    private let priceUpdateInterval: TimeInterval = 15.0
    private var isPriceUpdateInProgress = false
    
    // Cache for reducing API calls
    private var logoRequestsInProgress: Set<Int> = []
    
    // MARK: - Initialization
    // Sets up Combine bindings to respond to watchlist changes
    // Triggers initial load and starts periodic updates
    
    init(coinManager: CoinManager = CoinManager()) {
        self.coinManager = coinManager
        setupOptimizedBindings()
        loadInitialData()
        startOptimizedPeriodicUpdates()
        
        #if DEBUG
        print("🎯 WatchlistVM initialized with default sort: \(columnName(for: currentSortColumn)) \(currentSortOrder == .descending ? "DESC" : "ASC")")
        #endif
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
        requestCancellables.removeAll()
    }
    
    // MARK: - Optimized Public Methods
    
    /**
     * DATA LOADING IMPLEMENTATION
     *
     * Performance Improvements:
     * - Uses optimized watchlist manager's cached data
     * - Eliminates redundant database queries
     * - Smart loading states
     * - Efficient logo management
     */
    // Immediately pulls coins from watchlistManager
    // Starts fetching price data for those coins
    // Triggers UI Updates only after fresh prices are available
    
    func loadInitialData() {
        // Use optimized manager's instant O(1) data access
        let coins = watchlistManager.getWatchlistCoins()
        
        if coins.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.watchlistCoinsSubject.send([])
                self?.isLoadingSubject.send(false)
            }
            return
        }
        
        // Always fetch fresh price data first, don't show coins without prices
        refreshPriceData(for: coins)
    }
    
    
    func refreshWatchlist() {
        // Get instant data from watchlistManager
        let coins = watchlistManager.getWatchlistCoins()
        
        #if DEBUG
        print("🔄 Refreshing watchlist with \(coins.count) coins")
        #endif
        
        if coins.isEmpty {
            watchlistCoinsSubject.send([])
            isLoadingSubject.send(false)
        } else {
            // Always fetch fresh price data to ensure we have complete information
            refreshPriceData(for: coins)
        }
    }
    
    func removeFromWatchlist(_ coin: Coin) {
        // Use optimized manager's O(1) remove operation
        watchlistManager.removeFromWatchlist(coinId: coin.id)
        // No need to manually refresh - binding will handle it
    }
    
    func removeFromWatchlist(at index: Int) {
        guard index < currentWatchlistCoins.count else { return }
        let coin = currentWatchlistCoins[index]
        removeFromWatchlist(coin)
    }
    
    func isInWatchlist(coinId: Int) -> Bool {
        // Use optimized manager's O(1) lookup
        return watchlistManager.isInWatchlist(coinId: coinId)
    }
    
    func getWatchlistCount() -> Int {
        // Use optimized manager's O(1) count
        return watchlistManager.getWatchlistCount()
    }
    
    // MARK: - Optimized Private Methods
    
    /**
     * OPTIMIZED BINDING SETUP
     * 
     * Performance Improvements:
     * - Eliminates redundant loadWatchlistCoins() calls
     * - Direct binding to optimized manager's publishers
     * - Debounced updates to prevent UI thrashing
     * - Efficient change detection
     */
    private func setupOptimizedBindings() {
        // Direct binding to optimized manager's watchlist items
        watchlistManager.$watchlistItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                let coins = items.map { $0.toCoin() }
                self?.handleWatchlistChange(newCoins: coins)
            }
            .store(in: &cancellables)
        
        // Listen to optimized notifications (debounced)
        NotificationCenter.default.publisher(for: .watchlistDidUpdate)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                if let userInfo = notification.userInfo,
                   let action = userInfo["action"] as? String {
                    self.handleWatchlistNotification(action: action, userInfo: userInfo)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleWatchlistChange(newCoins: [Coin]) {
        let oldCoinIds = Set(currentWatchlistCoins.map { $0.id })
        let newCoinIds = Set(newCoins.map { $0.id })
        
        // Only update if there's an actual change
        if oldCoinIds != newCoinIds {
            // Don't update UI immediately with coins that have no price data
            // Instead, fetch prices first, then update UI with complete data
            if !newCoins.isEmpty {
                refreshPriceData(for: newCoins)
            } else {
                // If empty, update immediately
                watchlistCoinsSubject.send(newCoins)
            }
            
            // Clean up logos for removed coins
            let removedCoinIds = oldCoinIds.subtracting(newCoinIds)
            var updatedLogos = currentCoinLogos
            removedCoinIds.forEach { updatedLogos.removeValue(forKey: $0) }
            coinLogosSubject.send(updatedLogos)
        } else if !newCoins.isEmpty {
            // Same coins but maybe need sorting applied
            let currentCoins = currentWatchlistCoins
            watchlistCoinsSubject.send(newCoins)
            if currentCoins != newCoins {
                applySortingToWatchlist()
            }
        }
    }
    
    private func handleWatchlistNotification(action: String, userInfo: [AnyHashable: Any]) {
        switch action {
        case "add":
            if let coinId = userInfo["coinId"] as? Int {
                // Fetch logo for newly added coin
                fetchLogoIfNeeded(for: coinId)
            }
        case "batch_add", "batch_remove":
            // Refresh all logos for batch operations
            fetchMissingLogos(for: currentWatchlistCoins)
        default:
            break
        }
    }
    
    /**
     * OPTIMIZED PRICE FETCHING
     * 
     * Performance Improvements:
     * - Background processing
     * - Smart change detection
     * - Reduced API calls through caching
     * - Non-blocking UI updates
     */
    
    // Triggers background API call for price updates
    // Updates watchlistCoins with fresh quotes
    // Calls applySortingToWatchlist()
    // Triggers logo fetching in background
    
    private func refreshPriceData(for coins: [Coin]) {
        guard !coins.isEmpty else {
            watchlistCoinsSubject.send([])
            isLoadingSubject.send(false)
            return
        }
        
        isLoadingSubject.send(true)
        errorMessageSubject.send(nil)
        
        let coinIds = coins.map { $0.id }
        
        fetchPriceUpdates(for: coinIds) { [weak self] updatedCoins in
            DispatchQueue.main.async {
                #if DEBUG
                print("💰 Price data updated for \(updatedCoins.count) watchlist coins:")
                for coin in updatedCoins.prefix(3) {
                    if let quote = coin.quote?["USD"],
                       let price = quote.price,
                       let change = quote.percentChange24h {
                        print("   ✅ \(coin.symbol): $\(String(format: "%.2f", price)) (\(String(format: "%.2f", change))%)")
                    } else {
                        print("   ❌ \(coin.symbol): No price data")
                    }
                }
                if updatedCoins.count > 3 {
                    print("   ... and \(updatedCoins.count - 3) more")
                }
                #endif
                
                self?.watchlistCoinsSubject.send(updatedCoins)
                self?.isLoadingSubject.send(false)
                self?.lastPriceUpdate = Date()
                
                // Apply current sorting after price update
                self?.applySortingToWatchlist()
                
                // Fetch missing logos efficiently
                self?.fetchMissingLogos(for: updatedCoins)
            }
        }
    }
    
    
    // Uses Combine to fetch prices from coinManager.getQuotes
    // Handles error fallback to show old data if needed
    // Injects the new quotes into existing Coin models
    
    private func fetchPriceUpdates(for coinIds: [Int], completion: @escaping ([Coin]) -> Void) {
        guard !coinIds.isEmpty else {
            completion([])
            return
        }
        
        // Background price fetching
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🔄 Fetching fresh price data for \(coinIds.count) coins...")
            
            self.coinManager.getQuotes(for: coinIds)
                .sink(
                    receiveCompletion: { [weak self] completionResult in
                        if case .failure(let error) = completionResult {
                            DispatchQueue.main.async {
                                self?.errorMessageSubject.send(ErrorMessageProvider.shared.getWatchlistErrorMessage(for: error))
                                self?.isLoadingSubject.send(false)
                                self?.isPriceUpdateInProgress = false
                                
                                // Fallback: show coins without price data rather than empty list
                                let baseCoins = self?.watchlistManager.getWatchlistCoins() ?? []
                                if !baseCoins.isEmpty {
                                    self?.watchlistCoinsSubject.send(baseCoins)
                                    #if DEBUG
                                    print("⚠️ Price fetch failed, showing \(baseCoins.count) coins without price data")
                                    #endif
                                }
                            }
                        }
                    },
                    receiveValue: { [weak self] quotes in
                        guard let self = self else { return }
                        
                        #if DEBUG
                        print("📊 Quote API returned data for \(quotes.count) coins")
                        #endif
                        
                        // Use optimized manager's cached coins instead of redundant database calls
                        let baseCoins = self.watchlistManager.getWatchlistCoins()
                        
                        let updatedCoins = baseCoins.map { coin -> Coin in
                            var updatedCoin = coin
                            if let quote = quotes[coin.id] {
                                updatedCoin.quote = ["USD": quote]
                            }
                            return updatedCoin
                        }
                        
                        self.isPriceUpdateInProgress = false
                        completion(updatedCoins)
                    }
                )
                .store(in: &self.requestCancellables)
        }
    }
    
    /**
     * LOGO MANAGEMENT
     *
     * Performance Improvements:
     * - Request deduplication
     * - Batch logo fetching
     * - Local caching
     * - Background processing
     */
    
    
    // Checks which coins have missing logos
    // Avoids redundant calls using logoRequestInProgress
    // Uses Combine to get logos and Update UI
    
    private func fetchMissingLogos(for coins: [Coin]) {
        let coinsNeedingLogos = coins.filter { coin in
            currentCoinLogos[coin.id] == nil && !logoRequestsInProgress.contains(coin.id)
        }
        
        guard !coinsNeedingLogos.isEmpty else { return }
        
        let coinIds = coinsNeedingLogos.map { $0.id }
        logoRequestsInProgress.formUnion(coinIds)
        
        // Background logo fetching
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            self.coinManager.getCoinLogos(forIDs: coinIds)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] logos in
                    guard let self = self else { return }
                    let currentLogos = self.currentCoinLogos
                    let mergedLogos = currentLogos.merging(logos) { _, new in new }
                    self.coinLogosSubject.send(mergedLogos)
                    self.logoRequestsInProgress.subtract(coinIds)
                }
                .store(in: &self.requestCancellables)
        }
    }
    
    private func fetchLogoIfNeeded(for coinId: Int) {
        guard currentCoinLogos[coinId] == nil && !logoRequestsInProgress.contains(coinId) else { return }
        
        logoRequestsInProgress.insert(coinId)
        
        coinManager.getCoinLogos(forIDs: [coinId])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] logos in
                guard let self = self else { return }
                let currentLogos = self.currentCoinLogos
                let mergedLogos = currentLogos.merging(logos) { _, new in new }
                self.coinLogosSubject.send(mergedLogos)
                self.logoRequestsInProgress.remove(coinId)
            }
            .store(in: &requestCancellables)
    }
    
    /**
     * PERIODIC UPDATES
     * 
     * Performance Improvements:
     * - Smarter update intervals
     * - Background processing
     * - Prevents overlapping updates
     * - Efficient change detection
     */
    
    // Runs every 15 seconds (priceUpdateInterval)
    
    private func startOptimizedPeriodicUpdates() {
        // More intelligent update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: priceUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePricesIfNeeded()
        }
    }
    

    
    // Skips updates if nothing has changed or another fetch is in progress
    // Only updates watchlistCoins if prices actually changed
    
    private func updatePricesIfNeeded(force: Bool = false) {
        // Prevent overlapping updates
        guard !isPriceUpdateInProgress else { return }
        
        // Only update if we have coins and not currently loading
        guard !currentWatchlistCoins.isEmpty && !currentIsLoading else { return }
        
        // Check if enough time has passed (unless forced)
        let timeSinceLastUpdate = Date().timeIntervalSince(lastPriceUpdate)
        guard force || timeSinceLastUpdate >= priceUpdateInterval else { return }
        
        isPriceUpdateInProgress = true
        let coinIds = currentWatchlistCoins.map { $0.id }
        
        // Background price update
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            self.fetchPriceUpdates(for: coinIds) { [weak self] updatedCoins in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // Efficient change detection
                    let changedCoinIds = self.findChangedCoins(
                        current: self.currentWatchlistCoins,
                        updated: updatedCoins
                    )
                    
                    if !changedCoinIds.isEmpty {
                        self.watchlistCoinsSubject.send(updatedCoins)
                        self.updatedCoinIdsSubject.send(changedCoinIds)
                        self.lastPriceUpdate = Date()
                        
                        // Apply current sorting after periodic price update
                        self.applySortingToWatchlist()
                        
                        #if DEBUG
                        if !changedCoinIds.isEmpty {
                            print("💰 Periodic update: \(changedCoinIds.count) coins had price changes")
                        }
                        #endif
                    }
                    
                    self.isPriceUpdateInProgress = false
                }
            }
        }
    }
    
    
    private func findChangedCoins(current: [Coin], updated: [Coin]) -> Set<Int> {
        var changedIds = Set<Int>()
        
        let currentPrices = Dictionary(uniqueKeysWithValues: current.map { 
            ($0.id, $0.quote?["USD"]?.price ?? 0.0) 
        })
        
        for updatedCoin in updated {
            let newPrice = updatedCoin.quote?["USD"]?.price ?? 0.0
            let oldPrice = currentPrices[updatedCoin.id] ?? 0.0
            
            if abs(newPrice - oldPrice) > 0.001 { // Price changed significantly
                changedIds.insert(updatedCoin.id)
            }
        }
        
        return changedIds
    }
    
    
    func clearUpdatedCoinIds() {
        updatedCoinIdsSubject.send([])
    }
    
    // MARK: - Public Lifecycle Methods
    
    /**
     * PUBLIC TIMER CONTROL
     * 
     * These methods allow the view controller to control periodic updates
     * based on the tab's visibility state for better performance.
     */
    
    func startPeriodicUpdates() {
        startOptimizedPeriodicUpdates()
        #if DEBUG
        print("🔄 WatchlistVM: Started periodic price updates (15s interval)")
        #endif
    }
    
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        #if DEBUG
        print("⏸️ WatchlistVM: Stopped periodic price updates")
        #endif
    }
    
    func cancelAllRequests() {
        // Cancel any in-flight API requests (but keep UI bindings)
        requestCancellables.removeAll()
        isPriceUpdateInProgress = false
        isLoadingSubject.send(false)
        logoRequestsInProgress.removeAll()
        #if DEBUG
        print("🚫 WatchlistVM: Cancelled all in-flight API requests")
        #endif
    }
    
    // MARK: - Sorting Management
    
    /**
     * WATCHLIST SORTING SYSTEM
     * 
     * Sorting operates on the watchlist coins array for instant response.
     * Default sort is by descending rank (best ranked coins first: 1, 2, 3...).
     */
    
    func updateSorting(column: CryptoSortColumn, order: CryptoSortOrder) {
        currentSortColumn = column
        currentSortOrder = order
        
        #if DEBUG
        print("🔄 Watchlist sort: \(columnName(for: column)) - \(order == .descending ? "Descending" : "Ascending")")
        #endif
        
        // Apply sorting to current watchlist data instantly
        applySortingToWatchlist()
    }
    
    // Getter methods for current sort state (used by UI to sync sort header indicators)
    func getCurrentSortColumn() -> CryptoSortColumn {
        return currentSortColumn
    }
    
    func getCurrentSortOrder() -> CryptoSortOrder {
        return currentSortOrder
    }
    
    /**
     * DISPLAY NAME MAPPING FOR WATCHLIST
     * 
     * Converts internal enum values to user-friendly display names.
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
            return "24h Change"  // Watchlist uses fixed 24h change
        default:
            return "Unknown"
        }
    }
    
    /**
     * APPLY SORTING TO WATCHLIST COINS
     * 
     * This method provides immediate sorting of watchlist coins.
     * Maintains the current coins array and applies new sort order.
     */
    private func applySortingToWatchlist() {
        guard !currentWatchlistCoins.isEmpty else { return }
        
        #if DEBUG
        print("🔧 Sorting \(currentWatchlistCoins.count) watchlist coins by \(columnName(for: currentSortColumn))")
        #endif
        
        // Sort the watchlist coins
        let sortedCoins = sortCoins(currentWatchlistCoins)
        watchlistCoinsSubject.send(sortedCoins)  // This triggers UI update via AnyPublisher
        
        #if DEBUG
        if sortedCoins.count > 0 {
            let topSorted = Array(sortedCoins.prefix(3))
            let sortedDebug = topSorted.map { coin in
                let sortValue = getSortValue(for: coin, column: currentSortColumn)
                return "\(coin.symbol) (\(sortValue))"
            }.joined(separator: ", ")
            print("🔍 Top watchlist by \(columnName(for: currentSortColumn)): \(sortedDebug)")
        }
        #endif
    }
    
    /**
     * COMPREHENSIVE SORTING FOR WATCHLIST
     * 
     * This method handles sorting for all coin attributes with special logic for ranks.
     * The rank sorting is intentionally inverted to be user-friendly:
     * - "Descending" shows best ranks first (1, 2, 3...)
     * - "Ascending" shows worst ranks first (...3, 2, 1)
     */
    private func sortCoins(_ coins: [Coin]) -> [Coin] {
        return coins.sorted { coin1, coin2 in
            let ascending = (currentSortOrder == .ascending)
        
            switch currentSortColumn {
            case .rank:
                // Special rank logic: Descending = best ranks first (1,2,3...)
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
                // Watchlist uses 24h change
                let change1 = coin1.quote?["USD"]?.percentChange24h ?? 0
                let change2 = coin2.quote?["USD"]?.percentChange24h ?? 0
                return ascending ? (change1 < change2) : (change1 > change2)
                
            default:
                // Fallback: Default to rank sorting (best rank first)
                return coin1.cmcRank < coin2.cmcRank
            }
        }
    }
    
    /**
     * DISPLAY VALUE FORMATTING FOR WATCHLIST
     * 
     * Formats coin values for display in sort headers and debugging.
     */
    private func getSortValue(for coin: Coin, column: CryptoSortColumn) -> String {
        switch column {
        case .rank:
            return "#\(coin.cmcRank)"
        case .marketCap:
            let marketCap = coin.quote?["USD"]?.marketCap ?? 0
            return "$\(marketCap.abbreviatedString())"
        case .price:
            let price = coin.quote?["USD"]?.price ?? 0
            return String(format: "$%.2f", price)
        case .priceChange:
            let change = coin.quote?["USD"]?.percentChange24h ?? 0
            return String(format: "%.2f%%", change)
        default:
            return "N/A"
        }
    }
    
    // MARK: - Performance Monitoring
    
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "watchlistCount": currentWatchlistCoins.count,
            "logosCached": currentCoinLogos.count,
            "logoRequestsInProgress": logoRequestsInProgress.count,
            "lastPriceUpdate": lastPriceUpdate.timeIntervalSince1970,
            "isPriceUpdateInProgress": isPriceUpdateInProgress,
            "isLoading": currentIsLoading,
            "watchlistManagerMetrics": watchlistManager.getPerformanceMetrics()
        ]
    }
} 
