import Foundation

// MARK: - Persistence Service
final class PersistenceService {
    static let shared = PersistenceService()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let coinList = "cached_coin_list"
        static let coinLogos = "cached_coin_logos"
        static let lastCacheTime = "last_cache_time"
    }
    
    private init() {}
    
    // MARK: - Coin List Persistence
    
    func saveCoinList(_ coins: [Coin]) {
        do {
            let data = try JSONEncoder().encode(coins)
            userDefaults.set(data, forKey: Keys.coinList)
            userDefaults.set(Date(), forKey: Keys.lastCacheTime)
        } catch {
            print("❌ Failed to save coin list: \(error)")
        }
    }
    
    func loadCoinList() -> [Coin]? {
        guard let data = userDefaults.data(forKey: Keys.coinList) else { return nil }
        
        do {
            let coins = try JSONDecoder().decode([Coin].self, from: data)
            return coins
        } catch {
            print("❌ Failed to load coin list: \(error)")
            return nil
        }
    }
    
    // MARK: - Coin Logos Persistence
    
    func saveCoinLogos(_ logos: [Int: String]) {
        do {
            let data = try JSONEncoder().encode(logos)
            userDefaults.set(data, forKey: Keys.coinLogos)
        } catch {
            print("❌ Failed to save coin logos: \(error)")
        }
    }
    
    func loadCoinLogos() -> [Int: String]? {
        guard let data = userDefaults.data(forKey: Keys.coinLogos) else { return nil }
        
        do {
            let logos = try JSONDecoder().decode([Int: String].self, from: data)
            return logos
        } catch {
            print("❌ Failed to load coin logos: \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    
    func getLastCacheTime() -> Date? {
        return userDefaults.object(forKey: Keys.lastCacheTime) as? Date
    }
    
    func isCacheExpired(maxAge: TimeInterval = 300) -> Bool { // 5 minutes default
        guard let lastCacheTime = getLastCacheTime() else { return true }
        return Date().timeIntervalSince(lastCacheTime) > maxAge
    }
    
    func clearCache() {
        userDefaults.removeObject(forKey: Keys.coinList)
        userDefaults.removeObject(forKey: Keys.coinLogos)
        userDefaults.removeObject(forKey: Keys.lastCacheTime)
    }
    
    // MARK: - Offline Support
    
    func getOfflineData() -> (coins: [Coin], logos: [Int: String])? {
        guard let coins = loadCoinList() else { return nil }
        let logos = loadCoinLogos() ?? [:]
        return (coins: coins, logos: logos)
    }
    
    func saveOfflineData(coins: [Coin], logos: [Int: String]) {
        saveCoinList(coins)
        saveCoinLogos(logos)
    }
} 