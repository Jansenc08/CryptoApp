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
    private let apiKey = "f0e06275-928f-4732-8d8e-4834c56bf0b0"

    func fetchTopCoins(limit: Int = 100, convert: String = "USD", start: Int = 1) -> AnyPublisher<[Coin], NetworkError> {
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

}
