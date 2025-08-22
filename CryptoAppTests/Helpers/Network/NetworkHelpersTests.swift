import XCTest
import Combine
@testable import CryptoApp

final class NetworkHelpersTests: XCTestCase {
    func testCreateAPIRequestSetsHeadersAndMethod() {
        let url = URL(string: "https://api.test.com/path")!
        let request = URLSession.createAPIRequest(url: url, apiKey: "KEY")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-CMC_PRO_API_KEY"), "KEY")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testValidateResponse200PassesAndNon200Fails() {
        let data = Data("{}".utf8)
        let ok = HTTPURLResponse(url: URL(string: "https://a.b")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let bad = HTTPURLResponse(url: URL(string: "https://a.b")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        XCTAssertNoThrow(try URLSession.validateResponse((data: data, response: ok)))
        XCTAssertThrowsError(try URLSession.validateResponse((data: data, response: bad))) { error in
            XCTAssertEqual(error as? NetworkError, .invalidResponse)
        }
    }

    func testMapToNetworkError() {
        XCTAssertEqual(URLSession.mapToNetworkError(NetworkError.decodingError), .decodingError)
        XCTAssertEqual(URLSession.mapToNetworkError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))), .decodingError)
        let unknown = URLSession.mapToNetworkError(NSError(domain: "x", code: -1))
        if case .unknown = unknown { } else { XCTFail("Expected .unknown") }
    }
}


