import Foundation

struct Coin: Decodable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String?
    let numMarketPairs: Int?
    let dateAdded: String?
    let tags: [String]?
    let maxSupply: Double?
    let circulatingSupply: Double?
    let totalSupply: Double?
    let infiniteSupply: Bool?
    let cmcRank: Int
    let lastUpdated: String?
    let quote: [String: Quote]?

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, slug, tags, quote
        case numMarketPairs = "num_market_pairs"
        case dateAdded = "date_added"
        case maxSupply = "max_supply"
        case circulatingSupply = "circulating_supply"
        case totalSupply = "total_supply"
        case infiniteSupply = "infinite_supply"
        case cmcRank = "cmc_rank"
        case lastUpdated = "last_updated"
    }
}

