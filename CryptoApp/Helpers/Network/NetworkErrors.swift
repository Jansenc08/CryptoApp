//
//  NetworkError.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 4/7/25.
//

import Foundation

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

extension NetworkError: LocalizedError {
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
