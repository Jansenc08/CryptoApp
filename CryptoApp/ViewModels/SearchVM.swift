//
//  SearchVM.swift
//  CryptoApp
//
//  Created by AI Assistant on 1/7/25.
//

import Foundation
import Combine

// MARK: - Notification Names

extension Notification.Name {
    static let coinListCacheUpdated = Notification.Name("coinListCacheUpdated")
}

/**
 * SearchVM
 * 
 * ARCHITECTURE PATTERN: MVVM (Model-View-ViewModel)
 * - Handles search logic and state management
 * - Uses Combine debounce for efficient search input handling
 * - Filters existing coin data locally for best performance
 * - Integrates with existing CoinManager and caching system
 * 
 * SEARCH STRATEGY:
 * - Local filtering for instant results (uses cached coin data)
 * - Debounced input to prevent excessive filtering operations
 * - Searches across coin name, symbol, and slug
 * - Case-insensitive search with partial matching
 */
final class SearchVM: ObservableObject {
    
    // MARK: - Private Subjects (Internal State Management)
    
    /**
     * REACTIVE STATE MANAGEMENT WITH SUBJECTS
     * 
     * Using CurrentValueSubject for state that needs current values
     * This gives us more control over when and how values are published
     */
    
    private let searchTextSubject = CurrentValueSubject<String, Never>("")
    private let searchResultsSubject = CurrentValueSubject<[Coin], Never>([])
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = CurrentValueSubject<String?, Never>(nil)
    private let coinLogosSubject = CurrentValueSubject<[Int: String], Never>([:])
    
    // MARK: - Published AnyPublisher Properties
    
    /**
     * REACTIVE UI BINDING WITH ANYPUBLISHER
     * 
     * These AnyPublisher properties provide the same functionality as @Published
     * but give us more control over publishing behavior and transformations
     */
    
    var searchText: AnyPublisher<String, Never> {
        searchTextSubject.eraseToAnyPublisher()
    }
    
    var searchResults: AnyPublisher<[Coin], Never> {
        searchResultsSubject.eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    
    var errorMessage: AnyPublisher<String?, Never> {
        errorMessageSubject.eraseToAnyPublisher()
    }
    
    var coinLogos: AnyPublisher<[Int: String], Never> {
        coinLogosSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Current Value Accessors (For Internal Logic and ViewController Access)
    
    /**
     * INTERNAL STATE ACCESS
     * 
     * These computed properties provide access to current values
     * for both internal logic and ViewController access
     */
    
    private var currentSearchText: String {
        searchTextSubject.value
    }
    
    var currentSearchResults: [Coin] {
        searchResultsSubject.value
    }
    
    var currentCoinLogos: [Int: String] {
        coinLogosSubject.value
    }
    
    // MARK: - Public Properties for Cache Access
    
    /**
     * Access to cached coin data for improved recent search functionality
     */
    var cachedCoins: [Coin] {
        return allCoins
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var apiRequestCancellables = Set<AnyCancellable>() // Separate cancellables for API requests
    private let coinManager: CoinManagerProtocol
    private let persistenceService = PersistenceService.shared
    private var allCoins: [Coin] = []
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce
    
    // MARK: - Search Configuration
    
    private let maxSearchResults = 50 // Limit results for performance
    private let minimumSearchLength = 1 // Start searching after 1 character
    
    // MARK: - Lifecycle Management
    
    func cancelAllRequests() {
        // Cancel only API request subscriptions, NOT the core search functionality
        apiRequestCancellables.removeAll()
        
        // Reset loading state
        isLoadingSubject.send(false)
        
        print("🛑 SearchVM: Cancelled API requests (keeping search functionality intact)")
    }
    
    // MARK: - Init
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts CoinManagerProtocol for better testability and modularity.
     * Falls back to default CoinManager for backward compatibility.
     */
    init(coinManager: CoinManagerProtocol = CoinManager()) {
        self.coinManager = coinManager
        setupSearchDebounce()
        loadInitialData()
        setupCacheUpdateListener()
    }
    
    // MARK: - Cache Update Listener
    
    /**
     * CACHE UPDATE LISTENER
     * 
     * Listens for notifications when the main coin list updates the cache
     * and refreshes search data accordingly.
     */
    private func setupCacheUpdateListener() {
        NotificationCenter.default.publisher(for: .coinListCacheUpdated)
            .sink { [weak self] _ in
                print("🔍 Search: Received cache update notification")
                self?.refreshSearchData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search Setup
    
    /**
     * COMBINE DEBOUNCE IMPLEMENTATION
     * 
     * This sets up reactive search with debouncing to prevent excessive filtering.
     * - Debounces user input by 300ms
     * - Filters results on background queue
     * - Updates UI on main queue
     */
    private func setupSearchDebounce() {
        searchTextSubject
            .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(for: searchText)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    /**
     * INITIAL DATA LOADING
     * 
     * Uses only cached data for search to avoid interfering with main coin list pagination.
     * No background fetching to prevent API conflicts and state contamination.
     */
    private func loadInitialData() {
        // Only use cached data - no background fetching to avoid pagination conflicts
        if let cachedCoins = persistenceService.loadCoinList() {
            print("🔍 Search: Loaded \(cachedCoins.count) coins from cache for search")
            self.allCoins = cachedCoins
            
            // Load cached logos
            if let cachedLogos = persistenceService.loadCoinLogos() {
                coinLogosSubject.send(cachedLogos)
            }
        } else {
            print("🔍 Search: No cached coins available - search will be empty until main list loads data")
            self.allCoins = []
        }
        
        // Removed background fetch to prevent pagination interference
    }
    
        // MARK: - Removed Methods
    // fetchAllCoinsForSearch() and fetchCoinLogos() methods removed to prevent 
    // API conflicts with main coin list pagination
    
    // MARK: - Search Implementation
    
    /**
     * CORE SEARCH FUNCTIONALITY
     * 
     * Performs local search filtering with the following features:
     * - Case-insensitive matching
     * - Searches across name, symbol, and slug
     * - Partial matching support
     * - Results limited for performance
     * - Sorted by market cap (most relevant first)
     * - Uses only cached data to avoid API conflicts
     */
    private func performSearch(for searchText: String) {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear results if search text is too short
        guard trimmedText.count >= minimumSearchLength else {
            searchResultsSubject.send([])
            return
        }
        
        print("🔍 Search: Searching for '\(trimmedText)' in \(allCoins.count) cached coins")
        
        // Perform filtering on background queue for better performance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let lowercaseSearch = trimmedText.lowercased()
            
            let filteredCoins = self.allCoins.filter { coin in
                // Search in name
                if coin.name.lowercased().contains(lowercaseSearch) {
                    return true
                }
                
                // Search in symbol
                if coin.symbol.lowercased().contains(lowercaseSearch) {
                    return true
                }
                
                // Search in slug (if available)
                if let slug = coin.slug, slug.lowercased().contains(lowercaseSearch) {
                    return true
                }
                
                return false
            }
            
            // Sort by market cap (most relevant first) and limit results
            let sortedResults = filteredCoins
                .sorted { coin1, coin2 in
                    let marketCap1 = coin1.quote?["USD"]?.marketCap ?? 0
                    let marketCap2 = coin2.quote?["USD"]?.marketCap ?? 0
                    return marketCap1 > marketCap2
                }
                .prefix(self.maxSearchResults)
            
            // Update UI on main queue
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let results = Array(sortedResults)
                self.searchResultsSubject.send(results)
                print("🔍 Search: Found \(results.count) results for '\(trimmedText)'")
                
                // Fetch missing logos for search results
                self.fetchLogosIfNeeded(for: results)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /**
     * MANUAL SEARCH TRIGGER
     * 
     * Allows manual triggering of search (useful for initial load or refresh)
     */
    func triggerSearch() {
        performSearch(for: currentSearchText)
    }
    
    /**
     * CLEAR SEARCH
     * 
     * Clears search text and results
     */
    func clearSearch() {
        searchTextSubject.send("")
        searchResultsSubject.send([])
    }
    
    /**
     * UPDATE SEARCH TEXT
     * 
     * Updates the search text which will trigger debounced search
     */
    func updateSearchText(_ text: String) {
        searchTextSubject.send(text)
    }
    
    /**
     * REFRESH SEARCH DATA
     * 
     * Updates search data from current cache without making API calls.
     * Call this method when the main coin list has loaded fresh data.
     */
    func refreshSearchData() {
        // Only refresh from cache to avoid API conflicts
        if let cachedCoins = persistenceService.loadCoinList() {
            print("🔍 Search: Refreshed \(cachedCoins.count) coins from cache")
            self.allCoins = cachedCoins
            
            // Load updated logos
            if let cachedLogos = persistenceService.loadCoinLogos() {
                coinLogosSubject.send(cachedLogos)
            }
            
            // Re-perform current search with refreshed data
            performSearch(for: currentSearchText)
            
            // Also fetch logos for any existing search results
            let existingResults = currentSearchResults
            if !existingResults.isEmpty {
                fetchLogosIfNeeded(for: existingResults)
            }
        } else {
            print("🔍 Search: No cached data available for refresh")
            self.allCoins = []
            searchResultsSubject.send([])
        }
    }
    
    // MARK: - Logo Management
    
    /**
     * FETCH MISSING LOGOS FOR SEARCH RESULTS
     * 
     * Fetches logos for coins that appear in search results but don't have cached logos.
     * Uses low priority to avoid interfering with main data requests.
     */
    private func fetchLogosIfNeeded(for coins: [Coin]) {
        // Filter out coins that already have logos cached
        let coinsNeedingLogos = coins.filter { coin in
            currentCoinLogos[coin.id] == nil
        }
        
        guard !coinsNeedingLogos.isEmpty else {
            print("🔍 Search: All \(coins.count) result logos already cached")
            return
        }
        
        let coinIds = coinsNeedingLogos.map { $0.id }
        print("🔍 Search: Fetching \(coinIds.count) missing logos for search results")
        
        // Fetch missing logos with low priority - use API request cancellables
        coinManager.getCoinLogos(forIDs: coinIds, priority: .low)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLogos in
                guard let self = self else { return }
                
                print("🔍 Search: Received \(newLogos.count) new logos")
                
                // Merge new logos with existing cache
                let currentLogos = self.currentCoinLogos
                let mergedLogos = currentLogos.merging(newLogos) { _, new in new }
                self.coinLogosSubject.send(mergedLogos)
                
                // Update persistence cache with new logos
                self.persistenceService.saveCoinLogos(mergedLogos)
            }
            .store(in: &apiRequestCancellables) // Store in API-specific cancellables
    }
    
    // MARK: - Cleanup
    
    deinit {
        print("🧹 SearchVM deinit - cleaning up all subscriptions")
        cancellables.removeAll() // Remove persistent search subscriptions
        apiRequestCancellables.removeAll() // Remove API request subscriptions
    }
} 