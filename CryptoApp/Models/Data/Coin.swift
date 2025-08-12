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
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.usesGroupingSeparator = true
            
            // Dynamic decimal places based on price value (like CoinMarketCap)
            if price >= 1.0 {
                // For prices $1.00 and above: 2 decimal places
                formatter.maximumFractionDigits = 2
                formatter.minimumFractionDigits = 2
            } else if price >= 0.01 {
                // For prices $0.01 to $0.99: 4 decimal places
                formatter.maximumFractionDigits = 4
                formatter.minimumFractionDigits = 4
            } else if price >= 0.0001 {
                // For prices $0.0001 to $0.0099: 6 decimal places
                formatter.maximumFractionDigits = 6
                formatter.minimumFractionDigits = 2 // Don't force trailing zeros for small values
            } else {
                // For very small prices: 8 decimal places
                formatter.maximumFractionDigits = 8
                formatter.minimumFractionDigits = 2
            }
            
            if let formattedNumber = formatter.string(from: NSNumber(value: price)) {
                return "$\(formattedNumber)"
            } else {
                // Fallback for very small numbers that formatter can't handle
                if price < 0.00000001 {
                    return String(format: "$%.10f", price)
                } else {
                    return String(format: "$%.8f", price)
                }
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
    
    /// Identifies if this coin is a USD-pegged stablecoin (should be excluded from gainers/losers)
    /// Note: Asset-backed tokens like gold tokens (PAXG, XAUt) are NOT excluded per CoinMarketCap's approach
    var isStablecoin: Bool {
        // USD-pegged stablecoin symbols and names (excluding asset-backed tokens)
        let usdStablecoinSymbols = [
            "USDT", "USDC", "BUSD", "DAI", "TUSD", "USDP", "USDN", "UST", "FRAX",
            "LUSD", "SUSD", "GUSD", "HUSD", "USDD", "USTC", "FDUSD", "PYUSD"
            // Note: Removed PAXG, XAUt as they are gold-backed, not USD-pegged
        ]
        
        let usdStablecoinNames = [
            "tether", "usd-coin", "binance-usd", "dai", "trueusd", "paxos-standard",
            "neutrino-usd", "terraclassicusd", "frax", "liquity-usd", "nusd",
            "gemini-dollar", "husd", "usdd", "terra-luna", "first-digital-usd", "paypal-usd"
            // Note: Removed gold-related names
        ]
        
        // Check symbol (case-insensitive)
        if usdStablecoinSymbols.contains(where: { $0.lowercased() == symbol.lowercased() }) {
            return true
        }
        
        // Check name (case-insensitive)
        let lowercaseName = name.lowercased()
        if usdStablecoinNames.contains(where: { lowercaseName.contains($0) }) {
            return true
        }
        
        // Check slug if available (case-insensitive)
        if let slug = slug?.lowercased() {
            if usdStablecoinNames.contains(where: { slug.contains($0) }) {
                return true
            }
        }
        
        // Additional heuristics for USD stablecoins only
        if lowercaseName.contains("usd") && (lowercaseName.contains("stable") || lowercaseName.contains("dollar")) {
            // Exclude gold references
            if !lowercaseName.contains("gold") && !lowercaseName.contains("xau") {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Popular Coins Filtering Criteria (Matching CoinMarketCap)
    
    /// Check if coin meets CoinMarketCap's criteria for popular coins lists (gainers/losers)
    var meetsPopularCoinsCriteria: Bool {
        // Must not be a USD-pegged stablecoin (asset-backed tokens like gold are allowed)
        guard !isStablecoin else { return false }
        
        // CoinMarketCap includes ALL coins regardless of market cap rank (removed restriction)
        // They only filter by volume, not by top 100 market cap
        
        // Must have valid quote data
        guard let usdQuote = quote?["USD"] else { return false }
        
        // Must have valid price and market cap
        guard let _ = usdQuote.price, let _ = usdQuote.marketCap else { return false }
        
        // Must have valid 24h change data
        guard let _ = usdQuote.percentChange24h else { return false }
        
        // CoinMarketCap's actual volume requirement: $50,000 minimum (not $1M)
        if let volume24h = usdQuote.volume24h, volume24h < 50000 { // $50K minimum volume
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

