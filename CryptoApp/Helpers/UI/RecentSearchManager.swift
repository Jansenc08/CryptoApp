import Foundation

/**
 * RecentSearchItem
 * 
 * Represents a recent search with coin information
 */
struct RecentSearchItem: Codable {
    let coinId: Int
    let symbol: String
    let name: String
    let logoUrl: String?
    let slug: String? // Store the actual coin slug for proper CoinGecko API calls
    let timestamp: Date
    
    init(coinId: Int, symbol: String, name: String, logoUrl: String? = nil, slug: String? = nil) {
        self.coinId = coinId
        self.symbol = symbol
        self.name = name
        self.logoUrl = logoUrl
        self.slug = slug
        self.timestamp = Date()
    }
}

/**
 * RecentSearchManager
 * 
 * COIN-BASED RECENT SEARCHES for crypto app
 * - Stores coin information in UserDefaults (no API calls)
 * - Limits to 5 recent searches for clean UI
 * - Thread-safe operations
 * - Stores coin ID, symbol, name, and logo URL
 */
final class RecentSearchManager {
    
    static let shared = RecentSearchManager()
    
    private let userDefaults = UserDefaults.standard
    private let maxRecentSearches = 5
    private let recentSearchesKey = "recent_coin_searches"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /**
     * Add a coin to recent searches
     * - Removes duplicates by coin ID
     * - Moves to top if already exists
     * - Limits to maxRecentSearches
     */
    func addRecentSearch(coinId: Int, symbol: String, name: String, logoUrl: String? = nil, slug: String? = nil) {
        var recentSearches = getRecentSearchItems()
        
        // Remove if already exists (to move to top)
        recentSearches.removeAll { $0.coinId == coinId }
        
        // Create new item
        let newItem = RecentSearchItem(coinId: coinId, symbol: symbol, name: name, logoUrl: logoUrl, slug: slug)
        
        // Add to beginning
        recentSearches.insert(newItem, at: 0)
        
        // Limit to max count
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        // Save
        saveRecentSearchItems(recentSearches)
        AppLogger.search("Recent Search: Added \(symbol) (\(name)) with slug: \(slug ?? "nil") | Total: \(recentSearches.count)")
    }
    
    /**
     * Get all recent search items (most recent first)
     */
    func getRecentSearchItems() -> [RecentSearchItem] {
        guard let data = userDefaults.data(forKey: recentSearchesKey) else { return [] }
        
        do {
            let items = try JSONDecoder().decode([RecentSearchItem].self, from: data)
            return items
        } catch {
            AppLogger.error("Failed to load recent searches", error: error)
            return []
        }
    }
    
    /**
     * Get recent search symbols (for backward compatibility)
     */
    func getRecentSearches() -> [String] {
        return getRecentSearchItems().map { $0.symbol }
    }
    
    /**
     * Clear all recent searches
     */
    func clearRecentSearches() {
        userDefaults.removeObject(forKey: recentSearchesKey)
        AppLogger.search("Recent Search: Cleared all recent searches")
    }
    
    /**
     * Remove a specific coin by ID
     */
    func removeRecentSearch(coinId: Int) {
        var recentSearches = getRecentSearchItems()
        recentSearches.removeAll { $0.coinId == coinId }
        saveRecentSearchItems(recentSearches)
        AppLogger.search("Recent Search: Removed coin ID \(coinId)")
    }
    
    // MARK: - Private Methods
    
    private func saveRecentSearchItems(_ items: [RecentSearchItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: recentSearchesKey)
        } catch {
            AppLogger.error("Failed to save recent searches", error: error)
        }
    }
} 