import Foundation
import CoreData

// MARK: - WatchlistItem Extensions
extension WatchlistItem {
    
    // Computed properties for easier access
    var coinId: Int {
        return Int(id)
    }
    
    var rank: Int {
        return Int(cmcRank)
    }
    
    // Enhanced convenience initializer with additional fields
    convenience init(context: NSManagedObjectContext, coin: Coin, logoURL: String? = nil) {
        let entity = NSEntityDescription.entity(forEntityName: "WatchlistItem", in: context)!
        self.init(entity: entity, insertInto: context)
        
        // Basic fields
        self.id = Int32(coin.id)
        self.name = coin.name
        self.symbol = coin.symbol
        self.slug = coin.slug
        self.cmcRank = Int32(coin.cmcRank)
        self.dateAdded = Date()
        self.logoURL = logoURL
        
        // Store additional fields in the existing string/data fields using JSON encoding
        // This allows us to preserve complete coin data without modifying Core Data schema
        self.storeAdditionalData(coin)
    }
    
    // Store additional coin data as JSON in existing fields
    private func storeAdditionalData(_ coin: Coin) {
        let additionalData: [String: Any?] = [
            "numMarketPairs": coin.numMarketPairs,
            "maxSupply": coin.maxSupply,
            "circulatingSupply": coin.circulatingSupply,
            "totalSupply": coin.totalSupply,
            "infiniteSupply": coin.infiniteSupply,
            "dateAdded": coin.dateAdded,
            "tags": coin.tags,
            "lastUpdated": coin.lastUpdated
        ]
        
        // Convert to JSON and store in the new additionalData field
        if let jsonData = try? JSONSerialization.data(withJSONObject: additionalData.compactMapValues { $0 }),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.additionalData = jsonString
        }
    }
    
    // Retrieve additional coin data from JSON
    private func getAdditionalData() -> [String: Any] {
        guard let jsonString = self.additionalData,
              let jsonData = jsonString.data(using: .utf8),
              let data = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return [:]
        }
        return data
    }
    
    // Enhanced convert to Coin object with complete data
    func toCoin() -> Coin? {
        // Validate essential data before creating Coin object
        guard Int(id) > 0,
              let coinName = name, !coinName.isEmpty,
              let coinSymbol = symbol, !coinSymbol.isEmpty else {
            #if DEBUG
            print("⚠️ WatchlistItem.toCoin(): Skipping invalid watchlist item - ID: \(id), Name: '\(name ?? "nil")', Symbol: '\(symbol ?? "nil")'")
            #endif
            return nil
        }
        
        let additionalData = getAdditionalData()
        
        // Check if this is an old watchlist item without additional data
        let hasAdditionalData = !additionalData.isEmpty
        
        return Coin(
            id: Int(id),
            name: coinName,
            symbol: coinSymbol,
            slug: slug?.isEmpty == false ? slug : nil,
            numMarketPairs: hasAdditionalData ? (additionalData["numMarketPairs"] as? Int) : nil,
            dateAdded: hasAdditionalData ? (additionalData["dateAdded"] as? String) : nil,
            tags: hasAdditionalData ? (additionalData["tags"] as? [String]) : nil,
            maxSupply: hasAdditionalData ? (additionalData["maxSupply"] as? Double) : nil,
            circulatingSupply: hasAdditionalData ? (additionalData["circulatingSupply"] as? Double) : nil,
            totalSupply: hasAdditionalData ? (additionalData["totalSupply"] as? Double) : nil,
            infiniteSupply: hasAdditionalData ? (additionalData["infiniteSupply"] as? Bool) : nil,
            cmcRank: Int(cmcRank),
            lastUpdated: hasAdditionalData ? (additionalData["lastUpdated"] as? String) : nil,
            quote: nil // Fresh quotes are fetched separately by the WatchlistVM
        )
    }
} 
