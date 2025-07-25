import Foundation

struct Coin: Codable {
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
    var quote: [String: Quote]?

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
            // Use NumberFormatter with explicit $ symbol to avoid locale-specific "US$"
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            formatter.groupingSeparator = ","
            formatter.usesGroupingSeparator = true
            
            if let formattedNumber = formatter.string(from: NSNumber(value: price)) {
                return "$\(formattedNumber)"
            } else {
                return "$\(String(format: "%.2f", price))"
            }
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
    
    var percentChange24hValue: Double {
        return quote?["USD"]?.percentChange24h ?? 0.0
    }
    
    // MARK: - Dynamic Percentage Change Methods
    
    /// Returns percentage change string based on the specified filter
    func percentChangeString(for filter: PriceChangeFilter) -> String {
        let value = percentChangeValue(for: filter)
        return String(format: "%.2f%%", value)
    }
    
    /// Returns percentage change value based on the specified filter
    func percentChangeValue(for filter: PriceChangeFilter) -> Double {
        guard let usdQuote = quote?["USD"] else { return 0.0 }
        
        switch filter {
        case .oneHour:
            return usdQuote.percentChange1h ?? 0.0
        case .twentyFourHours:
            return usdQuote.percentChange24h ?? 0.0
        case .sevenDays:
            return usdQuote.percentChange7d ?? 0.0
        case .thirtyDays:
            return usdQuote.percentChange30d ?? 0.0
        }
    }
    
    /// Returns whether the change is positive based on the specified filter
    func isPositiveChange(for filter: PriceChangeFilter) -> Bool {
        return percentChangeValue(for: filter) >= 0
    }
    
    var isPositiveChange: Bool {
        return percentChange24hValue >= 0
    }
    
    var sparklineData: [Double] {
        // Generate sample sparkline data based on the 24h percentage change
        return SparklineView.generateSampleData(for: percentChange24hValue, points: 20)
    }

    var marketSupplyString: String {
        if let marketCap = quote?["USD"]?.marketCap {
            return "$" + marketCap.abbreviatedString()
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

