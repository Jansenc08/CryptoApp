import Foundation
import Combine

enum NetworkError: Error {
    case badURL
    case invalidResponse
    case decodingError
    case unknown(Error)
}

final class CoinService {

    private let baseURL = "https://pro-api.coinmarketcap.com/v1"
    private let apiKey = "9257c6de-ff87-48e2-886b-09f0cc34e666"
    private let coinGeckoBaseURL = "https://api.coingecko.com/api/v3" // CoinGecko Base URL
    
    // Dependencies
    private let cacheService = CacheService.shared
    private let requestManager = RequestManager.shared

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
            self?.cacheService.setCoinList(coins, limit: limit, start: start, convert: convert, sortType: sortType, sortDir: sortDir)
        })
        .eraseToAnyPublisher()
    }
    
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
    
    func fetchCoinLogos(forIDs ids: [Int], priority: RequestPriority = .low) -> AnyPublisher<[Int: String], Never> {
        print("🖼️ CoinService.fetchCoinLogos | Requested IDs: \(ids)")
        
        // Check cache first for logos too
        if let cachedLogos = cacheService.getCoinLogos(forIDs: ids) {
            print("💾 Cache hit for coin logos (IDs: \(ids)) | Found \(cachedLogos.count) logos")
            return Just(cachedLogos)
                .eraseToAnyPublisher()
        }
        
        print("🌐 CoinService.fetchCoinLogos | Cache miss, fetching from API...")
        
        // Use request manager with priority - logos get low priority since they're not urgent
        return requestManager.fetchCoinLogos(ids: ids, priority: priority) { [weak self] in
            self?.performCoinLogosRequest(forIDs: ids) ?? 
            Just([:]).eraseToAnyPublisher()
        }
        .replaceError(with: [:])
        .handleEvents(receiveOutput: { [weak self] logos in
            print("📥 CoinService.fetchCoinLogos | Received \(logos.count) logos: \(logos)")
            // Cache the result
            self?.cacheService.setCoinLogos(logos, forIDs: ids)
        })
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
    
    func fetchQuotes(for ids: [Int], convert: String, priority: RequestPriority = .normal) -> AnyPublisher<[Int: Quote], NetworkError> {
        // Check cache first for price quotes
        if let cachedQuotes = cacheService.getPriceUpdates(forIDs: ids, convert: convert) {
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
            self?.cacheService.setPriceUpdates(quotes, forIDs: ids, convert: convert)
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
    
    
    func fetchCoinGeckoChartData(for coinId: String, currency: String, days: String, priority: RequestPriority = .normal) -> AnyPublisher<[Double], NetworkError> {
        // Check cache first and return immediately if found
        // No rate limiting delays when data is cached. Makes filter switching instant
        if let cachedData = cacheService.getChartData(coinId: coinId, currency: currency, days: days) {
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
            self?.cacheService.setChartData(data, coinId: coinId, currency: currency, days: days)
            print("💾 Cached chart data for \(coinId) - \(days): \(data.count) points")
        })
        .eraseToAnyPublisher()
    }
    
    private func performChartDataRequest(for coinId: String, currency: String, days: String) -> AnyPublisher<[Double], NetworkError> {
        // Map CoinMarketCap slug to CoinGecko ID
        let geckoId = mapCMCSlugToGeckoId(coinId)
        let endpoint = "\(coinGeckoBaseURL)/coins/\(geckoId)/market_chart?vs_currency=\(currency)&days=\(days)"
        
        print("🔄 Mapping '\(coinId)' → '\(geckoId)'")
        print("🌐 CoinGecko URL: \(endpoint)")

        guard let url = URL(string: endpoint) else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET" // No API key needed for CoinGecko public endpoints

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    print("❌ No HTTP response")
                    throw NetworkError.invalidResponse
                }
                
                print("📡 CoinGecko response: HTTP \(response.statusCode)")
                
                if response.statusCode == 404 {
                    print("❌ CoinGecko: Coin '\(geckoId)' not found")
                    // Attempt to decode CoinGecko specific error message
                    if let errorResponse = try? JSONSerialization.jsonObject(with: output.data, options: []) as? [String: Any],
                       let errorMsg = errorResponse["error"] as? String {
                        print("❌ CoinGecko error: \(errorMsg)")
                    }
                    throw NetworkError.badURL
                } else if response.statusCode == 429 {
                    print("⚠️ CoinGecko: Rate limit exceeded (429). Requests too frequent.")
                    throw NetworkError.invalidResponse // Will trigger exponential backoff retry
                } else if response.statusCode != 200 {
                    print("❌ CoinGecko: HTTP \(response.statusCode)")
                    throw NetworkError.invalidResponse
                }
                return output.data
            }
            .decode(type: CoinGeckoChartResponse.self, decoder: JSONDecoder())
            .map { response in
                // CoinGecko returns prices as [[timestamp, price]]. We only want the price.
                let prices = response.prices.map { $0[1] }
                print("✅ Successfully fetched \(prices.count) price points for '\(geckoId)'")
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
