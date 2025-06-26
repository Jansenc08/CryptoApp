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

    func fetchTopCoins(limit: Int = 100, convert: String = "USD") -> AnyPublisher<[Coin], NetworkError> {
        let endpoint = "\(baseURL)/cryptocurrency/listings/latest?limit=\(limit)&convert=\(convert)"

        guard let url = URL(string: endpoint) else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return URLSession.shared.dataTaskPublisher(for: request)
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
}
