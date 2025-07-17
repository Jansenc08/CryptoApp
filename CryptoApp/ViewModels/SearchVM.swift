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
    
    // MARK: - Published Properties
    
    @Published var searchText: String = ""
    @Published var searchResults: [Coin] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var coinLogos: [Int: String] = [:]
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let coinManager: CoinManager
    private let persistenceService = PersistenceService.shared
    private var allCoins: [Coin] = []
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce
    
    // MARK: - Search Configuration
    
    private let maxSearchResults = 50 // Limit results for performance
    private let minimumSearchLength = 1 // Start searching after 1 character
    
    // MARK: - Init
    
    init(coinManager: CoinManager = CoinManager()) {
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
        $searchText
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
                self.coinLogos = cachedLogos
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
            searchResults = []
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
            DispatchQueue.main.async {
                self.searchResults = Array(sortedResults)
                print("🔍 Search: Found \(self.searchResults.count) results for '\(trimmedText)'")
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
        performSearch(for: searchText)
    }
    
    /**
     * CLEAR SEARCH
     * 
     * Clears search text and results
     */
    func clearSearch() {
        searchText = ""
        searchResults = []
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
                self.coinLogos = cachedLogos
            }
            
            // Re-perform current search with refreshed data
            performSearch(for: searchText)
        } else {
            print("🔍 Search: No cached data available for refresh")
            self.allCoins = []
            self.searchResults = []
        }
    }
} 