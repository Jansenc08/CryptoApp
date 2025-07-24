import Foundation
import Combine

/**
 * CoinService - Dual API Integration
 * 
 * - CoinMarketCap API: Used for coin listings, prices, metadata
 * - CoinGecko Demo API: Used for chart data and OHLC data
 * 
 * Rate Limits:
 * - CoinMarketCap: Professional plan limits
 * - CoinGecko Demo: 30 calls/minute (0.5 calls/second)
 */

enum NetworkError: Error, Equatable {
    case badURL
    case invalidResponse
    case decodingError
    case unknown(Error)
    
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.badURL, .badURL),
             (.invalidResponse, .invalidResponse),
             (.decodingError, .decodingError):
            return true
        case (.unknown, .unknown):
            return true // For simplicity, consider all unknown errors as equal
        default:
            return false
        }
    }
}

final class CoinService: CoinServiceProtocol {

    private let baseURL = "https://pro-api.coinmarketcap.com/v1"
    private let apiKey = "d90efe2f-8893-44bc-889e-919fc01684c5" // CoinMarketCap Demo API Key
    private let coinGeckoBaseURL = "https://api.coingecko.com/api/v3" // CoinGecko Base URL
    private let coinGeckoApiKey = "CG-yzBqmCqY8VybDQbMxbRZhaL9" // CoinGecko Demo API Key
    
    // Injected Dependencies
    private let cacheService: CacheServiceProtocol
    private let requestManager: RequestManagerProtocol
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Allows injection of dependencies for:
     * - Better testability with mock services
     * - Flexibility to swap implementations
     * - Cleaner separation of concerns
     * 
     * Falls back to shared instances for backward compatibility
     */
    init(
        cacheService: CacheServiceProtocol = CacheService.shared,
        requestManager: RequestManagerProtocol = RequestManager.shared
    ) {
        self.cacheService = cacheService
        self.requestManager = requestManager
    }

    
    
    // MARK: FetchTopCoins from CoinMarketCap
    // 1. Check cache for any existing result (based on limit, start)
    // 2. Uses RequestManager to throttle or prioritizes requests
    // 3. Calls performTopCoinsRequest() to hit actual API if no cache
    // 4. On success: stores result in cache & returns [Coin]
    
    func fetchTopCoins(limit: Int = 100, convert: String = "USD", start: Int = 1, sortType: String = "market_cap", sortDir: String = "desc", priority: RequestPriority = .normal) -> AnyPublisher<[Coin], NetworkError> {
        // Check cache first
        // Always check cache before making API calls to avoid unnecessary requests
        if let cachedCoins = cacheService.getCoinList(limit: limit, start: start, convert: convert, sortType: sortType, sortDir: sortDir) {
            print("💾 Cache hit for coin list (limit: \(limit), start: \(start))")
            return Just(cachedCoins)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // Use request manager with priority - I pass the priority through the entire chain
        return requestManager.fetchTopCoins(
            limit: limit,
            convert: convert,
            start: start,
            sortType: sortType,
            sortDir: sortDir,
            priority: priority
        ) { [weak self] in
            self?.performTopCoinsRequest(limit: limit, convert: convert, start: start, sortType: sortType, sortDir: sortDir) ?? 
            Fail(error: NetworkError.unknown(NSError(domain: "CoinService", code: -1, userInfo: nil)))
                .eraseToAnyPublisher()
        }
        .mapError { error in
            // Convert back to NetworkError
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.unknown(error)
            }
        }
        .handleEvents(receiveOutput: { [weak self] coins in
            // Cache the result for future use
            self?.cacheService.storeCoinList(coins, limit: limit, start: start, convert: convert, sortType: sortType, sortDir: sortDir)
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: Makes the real API Call to /cryptocurrency/listings/latest
    // 1. Constructs the URL using params like limit, start, convert, etc.
    // 2. Adds API key and headers.
    // 3. Uses URLSession.shared.dataTaskPublisher to fetch data.
    // 4. Decodes the response into my model MarketResponse.
    // 5. Emits [Coin] on the main thread.

    private func performTopCoinsRequest(limit: Int, convert: String, start: Int, sortType: String, sortDir: String) -> AnyPublisher<[Coin], NetworkError> {
        let endpoint = "\(baseURL)/cryptocurrency/listings/latest?limit=\(limit)&convert=\(convert)&start=\(start)&sort=\(sortType)&sort_dir=\(sortDir)"

        guard let url = URL(string: endpoint) else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Runs Network call on the background thread automatically
        // This runs in the background automatically (on a background thread).
        // Combine wraps this in a publisher so it becomes part of reactive chain
        return URLSession.shared.dataTaskPublisher(for: request)
            //Background thread (network/data parsing) 
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse,
                      response.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }

                return output.data
            }
            .decode(type: MarketResponse.self, decoder: {
                let decoder = JSONDecoder()
                return decoder
            }())
            .map { $0.data }
            .receive(on: DispatchQueue.main) // Switches to main thread
            .mapError { error in
                print("❌ Decoding failed with error: \(error)")
                if let error = error as? NetworkError {
                    return error
                } else if error is DecodingError {
                    return .decodingError
                } else {
                    return .unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    
    // MARK: Fetches logos (image URLs) for given coin IDs.
    // 1. Checks cache via cacheService.getCoinLogos.
    // 2. If not cached, uses RequestManager to prioritize the request.
    // 3. Calls performCoinLogosRequest to get logo URLs from:

    func fetchCoinLogos(forIDs ids: [Int], priority: RequestPriority = .low) -> AnyPublisher<[Int: String], Never> {
        print("🖼️ CoinService.fetchCoinLogos | Requested IDs: \(ids)")
        
        // PARTIAL CACHE LOGIC: Check which requested IDs are already cached
        let allCachedLogos = cacheService.getCoinLogos() ?? [:]
        let requestedCachedLogos = allCachedLogos.filter { ids.contains($0.key) }
        let missingIds = ids.filter { allCachedLogos[$0] == nil }
        
        print("💾 CoinService.fetchCoinLogos | Cache status: \(requestedCachedLogos.count)/\(ids.count) cached, \(missingIds.count) missing")
        
        // If all requested logos are cached, return them immediately
        if missingIds.isEmpty {
            print("✅ CoinService.fetchCoinLogos | All requested logos cached, returning \(requestedCachedLogos.count) logos")
            return Just(requestedCachedLogos)
                .eraseToAnyPublisher()
        }
        
        // If some logos are missing, fetch missing ones and merge with cached
        print("🌐 CoinService.fetchCoinLogos | Fetching \(missingIds.count) missing logos: \(missingIds)")
        
        // Use request manager with priority - logos get low priority since they're not urgent
        return requestManager.fetchCoinLogos(ids: missingIds, priority: priority) { [weak self] in
            self?.performCoinLogosRequest(forIDs: missingIds) ?? 
            Just([:]).eraseToAnyPublisher()
        }
        .replaceError(with: [:])
        .handleEvents(receiveOutput: { [weak self] newLogos in
            print("📥 CoinService.fetchCoinLogos | Received \(newLogos.count) new logos for missing IDs")
            // LOGO MERGE FIX: Merge new logos with existing cached logos instead of overwriting
            let existingLogos = self?.cacheService.getCoinLogos() ?? [:]
            let mergedLogos = existingLogos.merging(newLogos) { _, new in new }
            print("🔄 CoinService.fetchCoinLogos | Merging \(newLogos.count) new with \(existingLogos.count) existing = \(mergedLogos.count) total")
            // Cache the merged result
            self?.cacheService.storeCoinLogos(mergedLogos)
        })
        .map { newLogos in
            // RESPONSE MERGE: Combine cached + newly fetched logos for complete response
            let combinedResponse = requestedCachedLogos.merging(newLogos) { cached, _ in cached }
            print("📤 CoinService.fetchCoinLogos | Returning combined response: \(combinedResponse.count) logos for requested IDs")
            return combinedResponse
        }
        .eraseToAnyPublisher()
    }
    
    private func performCoinLogosRequest(forIDs ids: [Int]) -> AnyPublisher<[Int: String], Never> {
        let idString = ids.map { String($0) }.joined(separator: ",")
        guard let url = URL(string: "\(baseURL)/cryptocurrency/info?id=\(idString)") else {
            return Just([:]).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        request.httpMethod = "GET"

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output -> [Int: String] in
                guard let response = output.response as? HTTPURLResponse,
                      response.statusCode == 200 else {
                    return [:]
                }
                let json = try JSONSerialization.jsonObject(with: output.data) as? [String: Any]
                guard let dataDict = json?["data"] as? [String: Any] else {
                    return [:]
                }

                var result: [Int: String] = [:]
                for (key, value) in dataDict {
                    if let id = Int(key),
                       let info = value as? [String: Any],
                       let logo = info["logo"] as? String {
                        result[id] = logo
                    }
                }
                return result
            }
            .replaceError(with: [:])
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    
    // MARK: fetches live price + 24h change for a list of coin IDs
    // 1. Checks cache for price data.
    // 2. Uses RequestManager to manage request priority.
    // 3. Calls performQuotesRequest which: Hits /cryptocurrency/quotes/latest -> Parses nested JSON manually using JSONSerialization -> Extracts and decodes Quote objects
    // 4. Caches result and returns [Int: Quote]
    
    func fetchQuotes(for ids: [Int], convert: String, priority: RequestPriority = .normal) -> AnyPublisher<[Int: Quote], NetworkError> {
        // Check cache first for price quotes
        if let cachedQuotes = cacheService.getQuotes(for: ids, convert: convert) {
            print("💾 Cache hit for price quotes (IDs: \(ids))")
            return Just(cachedQuotes)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // Use request manager with priority
        return requestManager.fetchQuotes(
            ids: ids,
            convert: convert,
            priority: priority
        ) { [weak self] in
            self?.performQuotesRequest(for: ids, convert: convert) ?? 
            Fail(error: NetworkError.unknown(NSError(domain: "CoinService", code: -1, userInfo: nil)))
                .eraseToAnyPublisher()
        }
        .mapError { error in
            // Convert back to NetworkError
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.unknown(error)
            }
        }
        .handleEvents(receiveOutput: { [weak self] quotes in
            // Cache the result
            self?.cacheService.storeQuotes(quotes, for: ids, convert: convert)
        })
        .eraseToAnyPublisher()
    }
    
    private func performQuotesRequest(for ids: [Int], convert: String) -> AnyPublisher<[Int: Quote], NetworkError> {
        let idString = ids.map { String($0) }.joined(separator: ",")
        let endpoint = "\(baseURL)/cryptocurrency/quotes/latest?id=\(idString)&convert=\(convert)"

        guard let url = URL(string: endpoint) else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output -> [Int: Quote] in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }

                let json = try JSONSerialization.jsonObject(with: output.data) as? [String: Any]
                guard let dataDict = json?["data"] as? [String: Any] else {
                    throw NetworkError.decodingError
                }

                var result: [Int: Quote] = [:]
                for (key, coinData) in dataDict {
                    guard
                        let id = Int(key),
                        let coinDict = coinData as? [String: Any],
                        let quoteDict = coinDict["quote"] as? [String: Any],
                        let usdQuote = quoteDict[convert] as? [String: Any],
                        let quoteData = try? JSONSerialization.data(withJSONObject: usdQuote),
                        let quote = try? JSONDecoder().decode(Quote.self, from: quoteData)
                    else {
                        continue
                    }

                    result[id] = quote
                }

                return result
            }
            .mapError { error in
                (error as? NetworkError) ?? .unknown(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: Gets historical chart price points from CoinGecko.
    // 1. Checks Chart Data cache with key (coinId, currency, days)
    // 2. Uses RequestManager to prioritize
    // 3. Calls performChartRequest to hit -> /coins/{id}/market_chart?vs_currency=...&days=...
    
    // MARK: Gets real OHLC candlestick data from CoinGecko
    func fetchCoinGeckoOHLCData(for coinId: String, currency: String, days: String, priority: RequestPriority = .normal) -> AnyPublisher<[OHLCData], NetworkError> {
        // Check cache first
        let cacheKey = "ohlc_\(coinId)_\(currency)_\(days)"
        if let cachedData = cacheService.getOHLCData(for: coinId, currency: currency, days: days) {
            print("💾 ⚡ Instant cache hit for OHLC data: \(coinId) - \(days) (\(cachedData.count) candles)")
            return Just(cachedData)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        print("🌐 Cache miss for OHLC data: \(coinId) - \(days) (priority: \(priority.description))")
        
        return requestManager.fetchOHLCData(
            coinId: coinId,
            currency: currency,
            days: days,
            priority: priority
        ) { [weak self] in
            self?.performOHLCDataRequest(for: coinId, currency: currency, days: days) ??
            Fail(error: NetworkError.unknown(NSError(domain: "CoinService", code: -1, userInfo: nil)))
                .eraseToAnyPublisher()
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.unknown(error)
            }
        }
        .handleEvents(receiveOutput: { [weak self] data in
            self?.cacheService.storeOHLCData(data, for: coinId, currency: currency, days: days)
            print("💾 Cached OHLC data for \(coinId) - \(days): \(data.count) candles")
        })
        .eraseToAnyPublisher()
    }
    
    func fetchCoinGeckoChartData(for coinId: String, currency: String, days: String, priority: RequestPriority = .normal) -> AnyPublisher<[Double], NetworkError> {
        // Check cache first and return immediately if found
        // No rate limiting delays when data is cached. Makes filter switching instant
        if let cachedData = cacheService.getChartData(for: coinId, currency: currency, days: days) {
            print("💾 ⚡ Instant cache hit for chart data: \(coinId) - \(days) (\(cachedData.count) points)")
            return Just(cachedData)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        print("🌐 Cache miss for chart data: \(coinId) - \(days) (priority: \(priority.description))")
        
        // Use request manager with priority for non-cached data
        // High priority requests (filter changes) get processed faster
        return requestManager.fetchChartData(
            coinId: coinId,
            currency: currency,
            days: days,
            priority: priority
        ) { [weak self] in
            self?.performChartDataRequest(for: coinId, currency: currency, days: days) ?? 
            Fail(error: NetworkError.unknown(NSError(domain: "CoinService", code: -1, userInfo: nil)))
                .eraseToAnyPublisher()
        }
        .mapError { error in
            // Convert back to NetworkError
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.unknown(error)
            }
        }
        .handleEvents(receiveOutput: { [weak self] data in
            // Cache the result for future filter changes.
            self?.cacheService.storeChartData(data, for: coinId, currency: currency, days: days)
            print("💾 Cached chart data for \(coinId) - \(days): \(data.count) points")
        })
        .eraseToAnyPublisher()
    }
    
    private func performOHLCDataRequest(for coinId: String, currency: String, days: String) -> AnyPublisher<[OHLCData], NetworkError> {
        let geckoId = mapCMCSlugToGeckoId(coinId)
        let endpoint = "\(coinGeckoBaseURL)/coins/\(geckoId)/ohlc?vs_currency=\(currency)&days=\(days)"
        
        print("🔄 Mapping '\(coinId)' → '\(geckoId)' for OHLC data")
        print("🌐 CoinGecko OHLC URL: \(endpoint)")
        print("🔑 Using CoinGecko Demo API key: \(String(coinGeckoApiKey.prefix(8)))...")
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(coinGeckoApiKey, forHTTPHeaderField: "x-cg-demo-api-key")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    print("❌ No HTTP response for OHLC")
                    throw NetworkError.invalidResponse
                }
                
                print("📡 CoinGecko OHLC response: HTTP \(response.statusCode)")
                
                if response.statusCode == 404 {
                    print("❌ CoinGecko: OHLC data for '\(geckoId)' not found")
                    throw NetworkError.badURL
                } else if response.statusCode == 429 {
                    print("⚠️ CoinGecko: Rate limit exceeded (429) for OHLC")
                    throw NetworkError.invalidResponse
                } else if response.statusCode != 200 {
                    print("❌ CoinGecko OHLC: HTTP \(response.statusCode)")
                    throw NetworkError.invalidResponse
                }
                return output.data
            }
            .decode(type: CoinGeckoOHLCResponse.self, decoder: JSONDecoder())
            .map { response in
                let ohlcData = response.toOHLCData()
                print("✅ Successfully fetched \(ohlcData.count) OHLC candles for '\(geckoId)'")
                print("🔑 CoinGecko Demo API key working! Rate limit: 30 calls/minute")
                return ohlcData
            }
            .receive(on: DispatchQueue.main)
            .mapError { error in
                print("❌ CoinGecko OHLC fetch failed with error: \(error)")
                if let error = error as? NetworkError {
                    return error
                } else if error is DecodingError {
                    return .decodingError
                } else {
                    return .unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func performChartDataRequest(for coinId: String, currency: String, days: String) -> AnyPublisher<[Double], NetworkError> {
        // Map CoinMarketCap slug to CoinGecko ID -> Mapping happens here
        let geckoId = mapCMCSlugToGeckoId(coinId)
        let endpoint = "\(coinGeckoBaseURL)/coins/\(geckoId)/market_chart?vs_currency=\(currency)&days=\(days)"
        
        print("🔄 Mapping '\(coinId)' → '\(geckoId)'")
        print("🌐 CoinGecko URL: \(endpoint)")
        print("🔑 Using CoinGecko Demo API key: \(String(coinGeckoApiKey.prefix(8)))...")

        guard let url = URL(string: endpoint) else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(coinGeckoApiKey, forHTTPHeaderField: "x-cg-demo-api-key") // CoinGecko Demo API key

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    print("❌ No HTTP response")
                    throw NetworkError.invalidResponse
                }
                
                AppLogger.apiSummary(endpoint: "CoinGecko Chart", status: response.statusCode)
                
                if response.statusCode == 404 {
                    AppLogger.error("CoinGecko: Coin '\(geckoId)' not found")
                    throw NetworkError.badURL
                } else if response.statusCode == 429 {
                    AppLogger.error("CoinGecko: Rate limit exceeded - requests too frequent", error: nil)
                    throw NetworkError.invalidResponse // Will trigger exponential backoff retry
                } else if response.statusCode != 200 {
                    AppLogger.error("CoinGecko: HTTP \(response.statusCode)")
                    throw NetworkError.invalidResponse
                }
                return output.data
            }
            .decode(type: CoinGeckoChartResponse.self, decoder: JSONDecoder())
            .map { response in
                // CoinGecko returns prices as [[timestamp, price]]. We only want the price.
                let prices = response.prices.map { $0[1] }
                AppLogger.success("Fetched \(prices.count) price points for '\(geckoId)'")
                AppLogger.network("CoinGecko API key working | Rate limit: 30 calls/minute")
                return prices
            }
            .receive(on: DispatchQueue.main)
            .mapError { error in
                print("❌ CoinGecko Chart fetch failed with error: \(error)")
                if let error = error as? NetworkError {
                    return error
                } else if error is DecodingError {
                    return .decodingError
                } else {
                    return .unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Maps CoinMarketCap slugs to CoinGecko coin IDs
    private func mapCMCSlugToGeckoId(_ cmcSlug: String) -> String {
        let mapping: [String: String] = [
            // Top cryptocurrencies mapping - CMC slug : CoinGecko ID
            "bitcoin": "bitcoin",
            "ethereum": "ethereum", 
            "bnb": "binancecoin",         
            "solana": "solana",
            "xrp": "ripple",
            "dogecoin": "dogecoin",
            "cardano": "cardano",
            "avalanche": "avalanche-2",
            "polygon": "matic-network",
            "chainlink": "chainlink",
            "polkadot": "polkadot",
            "litecoin": "litecoin",
            "bitcoin-cash": "bitcoin-cash",
            "ethereum-classic": "ethereum-classic",
            "stellar": "stellar",
            "uniswap": "uniswap",
            "cosmos": "cosmos",
            "algorand": "algorand",
            "filecoin": "filecoin",
            "vechain": "vechain",
            "tron": "tron",
            "monero": "monero",
            "hedera": "hedera-hashgraph",
            "internet-computer": "internet-computer",
            "aave": "aave",
            "shiba-inu": "shiba-inu",
            "cronos": "crypto-com-chain",
            "near": "near",
            "aptos": "aptos",
            "quant": "quant-network",
            "arbitrum": "arbitrum",
            "optimism": "optimism",
            "maker": "maker",
            "fantom": "fantom",
            "mantle": "mantle",
            "rocket-pool": "rocket-pool",
            "kaspa": "kaspa",
            "thorchain": "thorchain",
            "flow": "flow",
            "pepe": "pepe",
            "bonk": "bonk",
            "floki": "floki"
        ]
        
        // Return mapped ID or fallback to original slug  
        return mapping[cmcSlug.lowercased()] ?? cmcSlug.lowercased()
    }
}
