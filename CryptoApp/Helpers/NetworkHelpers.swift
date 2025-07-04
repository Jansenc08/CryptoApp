//
//  NetworkHelper.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 4/7/25.
//

import Foundation
import Combine

// MARK: - URLSession Extensions
extension URLSession {
    
    // Creates a base network request with common headers
    static func createAPIRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        return request
    }
    
    // Validates HTTP response and extracts data
    static func validateResponse(_ output: URLSession.DataTaskPublisher.Output) throws -> Data {
        guard let response = output.response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw NetworkErrors.invalidResponse
        }
        return output.data
    }
    
    // Maps network/decoding errors to NetworkError cases
    static func mapToNetworkError(_ error: Error) -> NetworkErrors {
        print("❌ Network request failed with error: \(error)")
        
        if let networkError = error as? NetworkErrors {
            return networkError
        } else if error is DecodingError {
            return .decodingError
        } else {
            return .unknown(error)
        }
    }
}

// MARK: - Generic Network Service Protocol
protocol NetworkService {
    var baseURL: String { get }
    var apiKey: String { get }
}

extension NetworkService {
    
    func makeRequest<T: Codable>(
        endpoint: String,
        responseType: T.Type,
        additionalHeaders: [String: String] = [:]
    ) -> AnyPublisher<T, NetworkErrors> {
        
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail(error: .badURL).eraseToAnyPublisher()
        }
        
        var request = URLSession.createAPIRequest(url: url, apiKey: apiKey)
        
        // Add any additional headers
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap(URLSession.validateResponse)
            .decode(type: responseType, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .mapError(URLSession.mapToNetworkError)
            .eraseToAnyPublisher()
    }
}
