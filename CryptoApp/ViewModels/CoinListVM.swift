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

    // MARK: - Dependencies

    private let coinManager: CoinManager                   // Handles all API calls
    private var cancellables = Set<AnyCancellable>()       // Stores Combine subscriptions
    private let persistenceService = PersistenceService.shared // Handles offline persistence

    // MARK: - Pagination Properties

    private let itemsPerPage = 20                          // Number of coins to load per API request
    private var currentPage = 1                            // Current page number (used to calculate API offset)
    private var canLoadMore = true                         // Flag that indicates if more data can be fetched
    
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

    // MARK: - Initial Data Fetch

    func fetchCoins(convert: String = "USD", onFinish: (() -> Void)? = nil) {
        print("🔧 VM.fetchCoins | Called with completion: \(onFinish != nil)")
        
        // Check if we should skip this fetch due to recent activity
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            print("⏰ VM.fetchCoins | Skipped due to recent fetch")
            onFinish?()
            return
        }
        
        // Try to load offline data first if cache is not expired
        if !persistenceService.isCacheExpired(), let offlineData = persistenceService.getOfflineData() {
            print("💾 VM.fetchCoins | Using cached offline data")
            currentPage = 1
            canLoadMore = true
            coins = offlineData.coins
            coinLogos = offlineData.logos
            onFinish?()
            return
        }
        
        // Reset state for a fresh fetch
        print("\n🌟 Initial Load | Fetching coin data...")
        currentPage = 1
        canLoadMore = true
        coins = []
        isLoading = true
        errorMessage = nil
        lastFetchTime = Date()

        // Call API to fetch top coins (page 1) with NORMAL priority
        // I use normal priority for initial coin loading since it's important but not as urgent as filter changes
        coinManager.getTopCoins(limit: itemsPerPage, convert: convert, priority: .normal)
            .receive(on: DispatchQueue.main) // Ensure results update UI on main thread
            .sink { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    print("❌ VM.fetchCoins | Network error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    self?.canLoadMore = false // Prevent retry if error occurred
                    
                    // Try to load offline data as fallback
                    if let offlineData = self?.persistenceService.getOfflineData() {
                        self?.coins = offlineData.coins
                        self?.coinLogos = offlineData.logos
                        self?.errorMessage = "Using offline data due to network error"
                    }
                }
                print("🔄 VM.fetchCoins | Calling completion handler")
                onFinish?()
            } receiveValue: { [weak self] coins in
                print("✅ VM.fetchCoins | Network success: \(coins.count) coins")
                self?.coins = coins

                // Only allow loading more if we got a full page, and we haven't hit the 100 coin cap
                self?.canLoadMore = coins.count == self?.itemsPerPage && coins.count < 100

                // Start fetching logos for the coins (only if we don't already have them) with LOW priority
                // I use low priority for logos since they're visual enhancements, not critical data
                let ids = coins.map { $0.id }
                self?.fetchCoinLogosIfNeeded(forIDs: ids)
                
                // Save data for offline use
                self?.persistenceService.saveCoinList(coins)
            }
            .store(in: &cancellables)
    }

    // MARK: - Pagination (Triggered on Scroll)

    func loadMoreCoins(convert: String = "USD") {
        // Use debounced approach to prevent excessive API calls
        loadMoreSubject.send(convert)
    }
    
    private func performLoadMoreCoins(convert: String = "USD") {
        // Request guarding
        // Prevent multiple calls from running concurrently
        // Ignores triggers while request is still in flight
        // Prevent duplicate loads or loading past the max cap
        // Only load more if we are not already loading more coins & we are not already doing a full refresh / fetch 
        guard canLoadMore && !isLoadingMore && !isLoading else { 
            print("🚫 Pagination | Blocked | CanLoad: \(canLoadMore) | Loading: \(isLoading) | LoadingMore: \(isLoadingMore)")
            return 
        }

        // Do not load more than 100 coins
        if coins.count >= 100 {
            canLoadMore = false
            print("🛑 Pagination | Limit reached | 100 coins maximum")
            return
        }

        // Advance to next page and start loading
        currentPage += 1
        isLoadingMore = true
        errorMessage = nil
        
        print("📖 Pagination | Loading page \(currentPage) | Current: \(coins.count) coins")

        // Calculate start index for API pagination
        let start = (currentPage - 1) * itemsPerPage + 1

        // Use NORMAL priority for pagination requests
        // I use normal priority for pagination since users are actively scrolling and expect reasonable response times
        coinManager.getTopCoins(limit: itemsPerPage, convert: convert, start: start, priority: .normal)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingMore = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.currentPage -= 1 // Roll back page counter on failure
                }
            } receiveValue: { [weak self] newCoins in
                guard let self = self else { return }

                self.coins.append(contentsOf: newCoins)
                
                let totalCoins = self.coins.count
                print("✅ Pagination | Added \(newCoins.count) coins | Total: \(totalCoins)")

                // If fewer than 20 returned or 100 reached, stop loading more
                if totalCoins >= 100 || newCoins.count < self.itemsPerPage {
                    self.canLoadMore = false
                    print("🏁 Pagination | Complete | Total: \(totalCoins) | CanLoadMore: \(self.canLoadMore)")
                }

                // Fetch logos for newly appended coins (only if we don't already have them) with LOW priority
                // Again, logos are nice-to-have visual enhancements that can wait
                let newIds = newCoins.map { $0.id }
                self.fetchCoinLogosIfNeeded(forIDs: newIds)
            }
            .store(in: &cancellables)
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
        
        if !missingLogoIds.isEmpty {
            // Use LOW priority for logo fetching
            coinManager.getCoinLogos(forIDs: missingLogoIds, priority: .low)
                .sink { [weak self] logos in
                    // Merge new logos with existing ones (new overrides old if needed)
                    self?.coinLogos.merge(logos) { _, new in new }
                    
                    // Save updated logos for offline use
                    self?.persistenceService.saveCoinLogos(self?.coinLogos ?? [:])
                }
                .store(in: &cancellables)
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
