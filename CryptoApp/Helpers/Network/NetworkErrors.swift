//
//  NetworkError.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 4/7/25.
//

import Foundation

enum NetworkErrors: Error {
    case badURL
    case invalidResponse
    case decodingError
    case unknown(Error)
}

extension NetworkErrors: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
