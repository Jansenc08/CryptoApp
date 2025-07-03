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

extension Coin {
    var priceString: String {
        if let price = quote?["USD"]?.price {
            return String(format: "$%.2f", price)
        } else {
            return "N/A"
        }
    }
    var percentChange24hString: String {
        if let change = quote?["USD"]?.percentChange24h {
            return String(format: "%.2f%%", change)
        } else {
            return "N/A"
        }
    }

    var marketSupplyString: String {
        if let marketCap = quote?["USD"]?.marketCap {
            return "$" + marketCap.abbreviated()
        } else {
            return "N/A"
        }
    }
}


extension Coin: Hashable {
    static func == (lhs: Coin, rhs: Coin) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Double {
    func abbreviated() -> String {
        let num = abs(self)
        let sign = (self < 0) ? "-" : ""

        switch num {
        case 1_000_000_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000_000_000))T"
        case 1_000_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000_000))B"
        case 1_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000))M"
        case 1_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000))K"
        default:
            return "\(sign)\(String(format: "%.2f", num))"
        }
    }
}

