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

    func fetchTopCoins(limit: Int = 100, convert: String = "USD", start: Int = 1) -> AnyPublisher<[Coin], NetworkError> {
        // Check cache first
        if let cachedCoins = cacheService.getCoinList(limit: limit, start: start, convert: convert) {
            return Just(cachedCoins)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // Use request manager to handle deduplication
        return requestManager.fetchTopCoins(
            limit: limit,
            convert: convert,
            start: start
        ) { [weak self] in
            self?.performTopCoinsRequest(limit: limit, convert: convert, start: start) ?? 
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
            // Cache the result
            self?.cacheService.setCoinList(coins, limit: limit, start: start, convert: convert)
        })
        .eraseToAnyPublisher()
    }
    
    private func performTopCoinsRequest(limit: Int, convert: String, start: Int) -> AnyPublisher<[Coin], NetworkError> {
        let endpoint = "\(baseURL)/cryptocurrency/listings/latest?limit=\(limit)&convert=\(convert)&start=\(start)"

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
    
    func fetchCoinLogos(forIDs ids: [Int]) -> AnyPublisher<[Int: String], Never> {
        // Check cache first
        if let cachedLogos = cacheService.getCoinLogos(forIDs: ids) {
            return Just(cachedLogos)
                .eraseToAnyPublisher()
        }
        
        // Use request manager to handle deduplication
        return requestManager.fetchCoinLogos(ids: ids) { [weak self] in
            self?.performCoinLogosRequest(forIDs: ids) ?? 
            Just([:]).eraseToAnyPublisher()
        }
        .replaceError(with: [:])
        .handleEvents(receiveOutput: { [weak self] logos in
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
    
    func fetchQuotes(for ids: [Int], convert: String) -> AnyPublisher<[Int: Quote], NetworkError> {
        // Check cache first
        if let cachedQuotes = cacheService.getPriceUpdates(forIDs: ids, convert: convert) {
            return Just(cachedQuotes)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // Use request manager to handle deduplication
        return requestManager.fetchQuotes(
            ids: ids,
            convert: convert
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
    
    
    func fetchCoinGeckoChartData(for coinId: String, currency: String, days: String) -> AnyPublisher<[Double], NetworkError> {
        // Check cache first
        if let cachedData = cacheService.getChartData(coinId: coinId, currency: currency, days: days) {
            return Just(cachedData)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // Use request manager to handle deduplication
        return requestManager.fetchChartData(
            coinId: coinId,
            currency: currency,
            days: days
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
            // Cache the result
            self?.cacheService.setChartData(data, coinId: coinId, currency: currency, days: days)
        })
        .eraseToAnyPublisher()
    }
    
    private func performChartDataRequest(for coinId: String, currency: String, days: String) -> AnyPublisher<[Double], NetworkError> {
        let endpoint = "\(coinGeckoBaseURL)/coins/\(coinId)/market_chart?vs_currency=\(currency)&days=\(days)"

        guard let url = URL(string: endpoint) else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET" // No API key needed for CoinGecko public endpoints

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse,
                      response.statusCode == 200 else {
                    // Attempt to decode CoinGecko specific error message
                    if let errorResponse = try? JSONSerialization.jsonObject(with: output.data, options: []) as? [String: Any],
                       let _ = errorResponse["error"] as? String {
                        throw NetworkError.badURL
                    }
                    throw NetworkError.invalidResponse
                }
                return output.data
            }
            .decode(type: CoinGeckoChartResponse.self, decoder: JSONDecoder())
            .map { response in
                // CoinGecko returns prices as [[timestamp, price]]. We only want the price.
                return response.prices.map { $0[1] }
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
    
//    // MARK: - Fetch Top Coins (MOCKED)
//        func fetchTopCoins(limit: Int = 100, convert: String = "USD", start: Int = 1) -> AnyPublisher<[Coin], NetworkError> {
//            return Future<[Coin], NetworkError> { promise in
//                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
//                    guard let url = Bundle.main.url(forResource: "mock_top_coins", withExtension: "json") else {
//                        promise(.failure(.badURL))
//                        return
//                    }
//
//                    do {
//                        let data = try Data(contentsOf: url)
//                        let decoded = try JSONDecoder().decode(MarketResponse.self, from: data)
//                        promise(.success(decoded.data))
//                    } catch {
//                        print("❌ Mock TopCoins decoding failed:", error)
//                        promise(.failure(.decodingError))
//                    }
//                }
//            }
//            .receive(on: DispatchQueue.main)
//            .eraseToAnyPublisher()
//
//            /*
//            // LIVE API (commented out)
//            let endpoint = "\(baseURL)/cryptocurrency/listings/latest?limit=\(limit)&convert=\(convert)&start=\(start)"
//            ...
//            */
//        }
//
//        // MARK: - Fetch Quotes (MOCKED)
//        func fetchQuotes(for ids: [Int], convert: String) -> AnyPublisher<[Int: Quote], NetworkError> {
//            return Future<[Int: Quote], NetworkError> { promise in
//                DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
//                    guard let url = Bundle.main.url(forResource: "mock_quotes", withExtension: "json") else {
//                        promise(.failure(.badURL))
//                        return
//                    }
//
//                    do {
//                        let data = try Data(contentsOf: url)
//                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
//                        guard let dataDict = json?["data"] as? [String: Any] else {
//                            promise(.failure(.decodingError))
//                            return
//                        }
//
//                        var result: [Int: Quote] = [:]
//                        for (key, coinData) in dataDict {
//                            guard
//                                let id = Int(key),
//                                let coinDict = coinData as? [String: Any],
//                                let quoteDict = coinDict["quote"] as? [String: Any],
//                                let quoteForCurrency = quoteDict[convert] as? [String: Any],
//                                let quoteData = try? JSONSerialization.data(withJSONObject: quoteForCurrency),
//                                let quote = try? JSONDecoder().decode(Quote.self, from: quoteData)
//                            else { continue }
//
//                            result[id] = quote
//                        }
//
//                        promise(.success(result))
//                    } catch {
//                        print("❌ Mock Quotes decoding failed:", error)
//                        promise(.failure(.decodingError))
//                    }
//                }
//            }
//            .receive(on: DispatchQueue.main)
//            .eraseToAnyPublisher()
//
//            /*
//            // LIVE API (commented out)
//            let idString = ids.map { String($0) }.joined(separator: ",")
//            ...
//            */
//        }
//
//        // MARK: - Fetch Logos (MOCKED)
//        func fetchCoinLogos(forIDs ids: [Int]) -> AnyPublisher<[Int: String], Never> {
//            return Future<[Int: String], Never> { promise in
//                DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
//                    guard let url = Bundle.main.url(forResource: "mock_logos", withExtension: "json") else {
//                        promise(.success([:]))
//                        return
//                    }
//
//                    do {
//                        let data = try Data(contentsOf: url)
//                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
//                        guard let dataDict = json?["data"] as? [String: Any] else {
//                            promise(.success([:]))
//                            return
//                        }
//
//                        var result: [Int: String] = [:]
//                        for (key, value) in dataDict {
//                            if let id = Int(key),
//                               let info = value as? [String: Any],
//                               let logo = info["logo"] as? String {
//                                result[id] = logo
//                            }
//                        }
//
//                        promise(.success(result))
//                    } catch {
//                        print("❌ Mock Logos decoding failed:", error)
//                        promise(.success([:]))
//                    }
//                }
//            }
//            .receive(on: DispatchQueue.main)
//            .eraseToAnyPublisher()
//
//            /*
//            // LIVE API (commented out)
//            let idString = ids.map { String($0) }.joined(separator: ",")
//            ...
//            */
//        }
}
