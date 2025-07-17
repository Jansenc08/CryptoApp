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
    
    // Convenience initializer
    convenience init(context: NSManagedObjectContext, coin: Coin, logoURL: String? = nil) {
        let entity = NSEntityDescription.entity(forEntityName: "WatchlistItem", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = Int32(coin.id)
        self.name = coin.name
        self.symbol = coin.symbol
        self.slug = coin.slug
        self.cmcRank = Int32(coin.cmcRank)
        self.dateAdded = Date()
        self.logoURL = logoURL
    }
    
    // Convert to Coin object for use with existing UI
    func toCoin() -> Coin {
        return Coin(
            id: Int(id),
            name: name ?? "",
            symbol: symbol ?? "",
            slug: slug?.isEmpty == false ? slug : nil,
            numMarketPairs: nil,
            dateAdded: nil,
            tags: nil,
            maxSupply: nil,
            circulatingSupply: nil,
            totalSupply: nil,
            infiniteSupply: nil,
            cmcRank: Int(cmcRank),
            lastUpdated: nil,
            quote: nil
        )
    }
} 
