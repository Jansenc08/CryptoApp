import XCTest
@testable import CryptoApp

final class ErrorMessageProviderTests: XCTestCase {
    func testRequestErrorMessages() {
        let ctx = ErrorContext(feature: .coinList)
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: RequestError.rateLimited, context: ctx).contains("temporarily"))
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: RequestError.throttled, context: ctx).contains("paced") || ErrorMessageProvider.shared.getMessage(for: RequestError.throttled, context: ctx).contains("throttled"))
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: RequestError.duplicateRequest, context: ctx).count > 0)
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: RequestError.castingError, context: ctx).count > 0)
    }

    func testNetworkErrorMessages() {
        let ctx = ErrorContext(feature: .search)
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: NetworkError.badURL, context: ctx).count > 0)
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: NetworkError.invalidResponse, context: ctx).count > 0)
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: NetworkError.decodingError, context: ctx).count > 0)
        XCTAssertTrue(ErrorMessageProvider.shared.getMessage(for: NetworkError.unknown(NSError(domain: "", code: -1)), context: ctx).count > 0)
    }

    func testRetryInfoFlags() {
        let ctx = ErrorContext(feature: .chartData(symbol: "BTC"))
        XCTAssertTrue(ErrorMessageProvider.shared.getRetryInfo(for: RequestError.rateLimited, context: ctx).isRetryable)
        XCTAssertTrue(ErrorMessageProvider.shared.getRetryInfo(for: RequestError.throttled, context: ctx).isRetryable)
        XCTAssertFalse(ErrorMessageProvider.shared.getRetryInfo(for: RequestError.duplicateRequest, context: ctx).isRetryable)
        XCTAssertTrue(ErrorMessageProvider.shared.getRetryInfo(for: NetworkError.badURL, context: ctx).isRetryable == false)
    }
}


