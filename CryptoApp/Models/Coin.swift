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
    
    // MARK: - Stablecoin Detection
    
    /// Identifies if this coin is a stablecoin (should be excluded from gainers/losers)
    var isStablecoin: Bool {
        // Common stablecoin symbols and names
        let stablecoinSymbols = [
            "USDT", "USDC", "BUSD", "DAI", "TUSD", "USDP", "USDN", "UST", "FRAX",
            "LUSD", "SUSD", "GUSD", "HUSD", "USDD", "USTC", "FDUSD", "PYUSD"
        ]
        
        let stablecoinNames = [
            "tether", "usd-coin", "binance-usd", "dai", "trueusd", "paxos-standard",
            "neutrino-usd", "terraclassicusd", "frax", "liquity-usd", "nusd",
            "gemini-dollar", "husd", "usdd", "terra-luna", "first-digital-usd", "paypal-usd"
        ]
        
        // Check symbol (case-insensitive)
        if stablecoinSymbols.contains(where: { $0.lowercased() == symbol.lowercased() }) {
            return true
        }
        
        // Check name (case-insensitive)
        let lowercaseName = name.lowercased()
        if stablecoinNames.contains(where: { lowercaseName.contains($0) }) {
            return true
        }
        
        // Check slug if available (case-insensitive)
        if let slug = slug?.lowercased() {
            if stablecoinNames.contains(where: { slug.contains($0) }) {
                return true
            }
        }
        
        // Additional heuristics for stablecoins
        if lowercaseName.contains("usd") && (lowercaseName.contains("stable") || lowercaseName.contains("dollar")) {
            return true
        }
        
        return false
    }
    
    // MARK: - Popular Coins Filtering Criteria
    
    /// Check if coin meets criteria for popular coins lists (gainers/losers)
    var meetsPopularCoinsCriteria: Bool {
        // Must not be a stablecoin
        guard !isStablecoin else { return false }
        
        // Must be in top ~75 by market cap rank (mobile app behavior)
        guard cmcRank <= 75 else { return false }
        
        // Must have valid quote data
        guard let usdQuote = quote?["USD"] else { return false }
        
        // Must have valid price and market cap
        guard let _ = usdQuote.price, let _ = usdQuote.marketCap else { return false }
        
        // Must have valid 24h change data
        guard let _ = usdQuote.percentChange24h else { return false }
        
        // Must have sufficient trading volume (basic quality filter)
        if let volume24h = usdQuote.volume24h, volume24h < 1000000 { // $1M minimum volume
            return false
        }
        
        return true
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

