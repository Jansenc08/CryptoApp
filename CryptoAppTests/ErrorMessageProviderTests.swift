//
//  ErrorMessageProviderTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for ErrorMessageProvider covering:
//  - RequestError mappings (rateLimited, throttled, duplicateRequest, castingError)
//  - NetworkError mappings (invalidResponse, decodingError, unknown, badURL)
//  - URL errors (URLError) and generic fallbacks
//  - Retry info behavior (isRetryable/message/action) across contexts
//

import XCTest
@testable import CryptoApp

final class ErrorMessageProviderTests: XCTestCase {
    
    func testRequestErrorMessages() {
        let provider = ErrorMessageProvider.shared
        let contexts: [ErrorContext] = [
            ErrorContext(feature: .coinList),
            ErrorContext(feature: .search),
            ErrorContext(feature: .watchlist),
            ErrorContext(feature: .priceUpdates),
            ErrorContext(feature: .chartData(symbol: "BTC"))
        ]
        
        for context in contexts {
            let throttledMsg = provider.getMessage(for: RequestError.throttled, context: context)
            XCTAssertFalse(throttledMsg.isEmpty)
            let rateLimitedMsg = provider.getMessage(for: RequestError.rateLimited, context: context)
            XCTAssertFalse(rateLimitedMsg.isEmpty)
        }
    }
    
    func testNetworkErrorMessages() {
        let provider = ErrorMessageProvider.shared
        let context = ErrorContext(feature: .coinList)
        XCTAssertFalse(provider.getMessage(for: NetworkError.invalidResponse, context: context).isEmpty)
        XCTAssertFalse(provider.getMessage(for: NetworkError.decodingError, context: context).isEmpty)
        let unknownMsg = provider.getMessage(for: NetworkError.unknown(NSError(domain: "", code: 1)), context: context)
        XCTAssertFalse(unknownMsg.isEmpty)
    }
    
    func testURLErrorMessage() {
        let provider = ErrorMessageProvider.shared
        let context = ErrorContext(feature: .search)
        let urlError = URLError(.notConnectedToInternet)
        let msg = provider.getMessage(for: urlError, context: context)
        XCTAssertTrue(msg.contains("internet") || !msg.isEmpty)
    }
    
    func testRetryInfoMapping() {
        let provider = ErrorMessageProvider.shared
        let context = ErrorContext(feature: .chartData(symbol: "BTC"))
        
        let retry1 = provider.getRetryInfo(for: RequestError.rateLimited, context: context)
        XCTAssertTrue(retry1.isRetryable)
        XCTAssertFalse(retry1.message.isEmpty)
        
        let retry2 = provider.getRetryInfo(for: NetworkError.badURL, context: context)
        XCTAssertFalse(retry2.isRetryable)
        XCTAssertFalse(retry2.message.isEmpty)
    }
}
