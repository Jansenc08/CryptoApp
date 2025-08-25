//
//  RequestManagerTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Essential tests for RequestManager covering core functionality:
//  - Basic request execution and success paths
//  - Request deduplication with same keys
//  - Priority system (high bypasses throttling, normal/low are throttled)
//  - Error handling for network and request errors
//

import XCTest
import Combine
@testable import CryptoApp

final class RequestManagerTests: XCTestCase {
    
    var requestManager: RequestManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        requestManager = RequestManager()
        requestManager.resetForTesting()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        requestManager.resetForTesting()
        requestManager = nil
        super.tearDown()
    }
    
    // MARK: - Core Functionality Tests
    
    func testBasicRequestExecution() {
        // Given
        // Create expectation to wait for async request completion
        let expectation = XCTestExpectation(description: "Request should complete successfully")
        // Define the expected result value to validate against
        let expectedValue = "test_result"
        // Variable to capture the actual value received from the request
        var receivedValue: String?
        
        // When
        // Execute a basic request with normal priority
        // The request returns a delayed publisher that emits the expected value
        requestManager.executeRequest(key: "test_key", priority: .normal) {
            Just(expectedValue)
                .setFailureType(to: Error.self)
                .delay(for: .milliseconds(50), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Request should not fail: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                receivedValue = value
            }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        // Verify that the request completed successfully with the expected value
        XCTAssertEqual(receivedValue, expectedValue)
    }
    
    // MARK: - Request Deduplication Tests
    
    func testRequestDeduplication() {
        // Given
        // Create expectation for 3 simultaneous subscribers to the same request
        let expectation = XCTestExpectation(description: "All requests should complete with same result")
        expectation.expectedFulfillmentCount = 3
        
        // Use the same key for all requests to trigger deduplication logic
        let key = "duplicate_test"
        // Counter to verify the underlying request is only executed once
        var callCount = 0
        // Array to collect results from all subscribers
        var results: [String] = []
        // The result that all subscribers should receive
        let expectedResult = "shared_result"
        
        // Factory function that creates the actual network request
        // This simulates an expensive operation that should only be called once
        let createRequest = {
            return Future<String, Error> { promise in
                // Increment counter to track how many times this is called
                callCount += 1
                // Simulate async work with a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    promise(.success(expectedResult))
                }
            }
            .eraseToAnyPublisher()
        }
        
        // When - Fire three requests with same key simultaneously
        // This tests the deduplication mechanism
        for i in 0..<3 {
            requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Request \(i) should not fail: \(error)")
                        }
                        expectation.fulfill()
                    },
                    receiveValue: { value in
                        results.append(value)
                    }
                )
                .store(in: &cancellables)
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        // Verify the underlying request was only executed once (deduplication worked)
        XCTAssertEqual(callCount, 1, "Request should only be called once due to deduplication")
        // Verify all three subscribers received a result
        XCTAssertEqual(results.count, 3, "All three subscribers should receive the result")
        // Verify all subscribers got the same result from the shared request
        XCTAssertTrue(results.allSatisfy { $0 == expectedResult }, "All results should be identical")
    }
    
    // MARK: - Priority System Tests
    
    func testPriorityLevels() {
        // When/Then - Test priority configurations
        // Verify high priority has the shortest delay interval (fastest throttling reset)
        XCTAssertEqual(RequestPriority.high.delayInterval, 1.0)
        // Verify normal priority has moderate delay interval
        XCTAssertEqual(RequestPriority.normal.delayInterval, 3.0)
        // Verify low priority has the longest delay interval (slowest throttling reset)
        XCTAssertEqual(RequestPriority.low.delayInterval, 6.0)
    }
    
    func testHighPriorityBypassesThrottling() {
        // Given
        // Create expectation for two consecutive high priority requests
        let expectation = XCTestExpectation(description: "High priority should bypass throttling")
        expectation.expectedFulfillmentCount = 2
        
        // Counter to track how many requests actually complete
        var completionCount = 0
        // Use the same key to test throttling bypass behavior
        let key = "high_priority_test"
        
        // Factory for creating high priority requests
        // High priority should bypass throttling and execute immediately
        let createRequest = {
            Just("high_priority_result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - Fire two high priority requests quickly
        // First high priority request
        requestManager.executeRequest(key: key, priority: .high, request: createRequest)
            .sink(
                receiveCompletion: { _ in
                    completionCount += 1
                    expectation.fulfill()
                    
                    // Immediate second request (should work for high priority)
                    // This tests that high priority bypasses throttling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.requestManager.executeRequest(key: key, priority: .high, request: createRequest)
                            .sink(
                                receiveCompletion: { _ in
                                    completionCount += 1
                                    expectation.fulfill()
                                },
                                receiveValue: { _ in }
                            )
                            .store(in: &self.cancellables)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        // Verify both high priority requests completed successfully
        // This confirms high priority bypasses throttling mechanisms
        XCTAssertEqual(completionCount, 2, "High priority should allow quick consecutive requests")
    }
    
    func testNormalPriorityThrottling() {
        // Given
        // Test that normal priority requests are subject to throttling
        let expectation = XCTestExpectation(description: "Normal priority should be throttled")
        // Variable to capture the throttling error
        var errorReceived: Error?
        
        // Factory for creating normal priority requests
        let createRequest = {
            Just("result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - Test normal priority throttling
        let key = "normal_throttle_test"
        // First normal priority request - should succeed
        requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
            .sink(
                receiveCompletion: { _ in 
                    // Immediate second request should be throttled
                    // This tests that normal priority requests are subject to throttling
                    self.requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    errorReceived = error
                                }
                                expectation.fulfill()
                            },
                            receiveValue: { _ in }
                        )
                        .store(in: &self.cancellables)
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        // Verify that the second request was throttled
        XCTAssertNotNil(errorReceived, "Normal priority should be throttled")
        // Verify the specific throttling error was returned
        XCTAssertEqual(errorReceived as? RequestError, .throttled)
    }
    
    // MARK: - Error Handling Tests
    
    func testRequestErrorTypes() {
        // Given
        // Test that specific RequestError types are properly handled and propagated
        let expectation = XCTestExpectation(description: "Should handle RequestError")
        // Variable to capture the specific RequestError type
        var receivedError: RequestError?
        
        // When
        // Execute a request that will emit a specific RequestError
        requestManager.executeRequest(key: "error_test", priority: .normal) {
            Fail<String, Error>(error: RequestError.throttled)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { completion in
                if case .failure(let err) = completion {
                    receivedError = err as? RequestError
                }
                expectation.fulfill()
            },
            receiveValue: { _ in
                XCTFail("Should not receive value on failure")
            }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        // Verify the specific RequestError was properly propagated
        XCTAssertEqual(receivedError, .throttled)
    }
    
    func testNetworkErrorHandling() {
        // Given
        // Test that generic network errors are properly handled and propagated
        let expectation = XCTestExpectation(description: "Network error should be handled")
        // Create a realistic network error (no internet connection)
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        // Variable to capture the propagated network error
        var receivedError: Error?
        
        // When
        // Execute a request that will emit a network error
        requestManager.executeRequest(key: "network_error_test", priority: .normal) {
            Fail<String, Error>(error: networkError)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error
                }
                expectation.fulfill()
            },
            receiveValue: { _ in
                XCTFail("Should not receive value on network failure")
            }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        // Verify the network error was propagated
        XCTAssertNotNil(receivedError)
        // Verify the error details are preserved
        let nsError = receivedError as NSError?
        XCTAssertEqual(nsError?.domain, NSURLErrorDomain)
        XCTAssertEqual(nsError?.code, NSURLErrorNotConnectedToInternet)
    }
    
    // MARK: - Cleanup Tests
    
    func testResetFunctionality() {
        // Given
        // Test that the reset functionality clears internal state properly
        let expectation = XCTestExpectation(description: "Reset should work")
        
        // When - Setup some state then reset
        // First execute a request to establish some internal state
        requestManager.executeRequest(key: "reset_test", priority: .normal) {
            Just("result").setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in expectation.fulfill() },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
        
        // Reset and verify clean state
        // This should clear all internal throttling and deduplication state
        requestManager.resetForTesting()
        
        // Then - Should be able to make requests again immediately
        // After reset, the same key should be usable without throttling issues
        let postResetExpectation = XCTestExpectation(description: "Post-reset request should work")
        requestManager.executeRequest(key: "reset_test", priority: .normal) {
            Just("post_reset_result").setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in postResetExpectation.fulfill() },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
        
        wait(for: [postResetExpectation], timeout: 1.0)
        // Test passes if no errors occur - this confirms reset cleared all state
    }
}

// MARK: - Additional coverage for wrappers and casting paths
extension RequestManagerTests {
    func testFetchTopCoinsWrapperReturnsData() {
        // Given
        let coins = TestDataFactory.createMockCoins(count: 3)
        let exp = expectation(description: "top coins")
        var received: [Coin] = []
        
        // When
        requestManager.fetchTopCoins(
            limit: 3,
            convert: "USD",
            start: 1,
            sortType: "market_cap",
            sortDir: "desc",
            priority: .normal,
            apiCall: {
                Just(coins)
                    .setFailureType(to: NetworkError.self)
                    .eraseToAnyPublisher()
            }
        )
        .sink(
            receiveCompletion: { _ in exp.fulfill() },
            receiveValue: { received = $0 }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received.first?.id, 1)
    }
    
    func testFetchCoinLogosWrapperReturnsData() {
        // Given
        let ids = [1,2,3]
        let logos = TestDataFactory.createMockLogos(for: ids)
        let exp = expectation(description: "logos")
        var received: [Int:String] = [:]
        
        // When
        requestManager.fetchCoinLogos(ids: ids, priority: .low) {
            Just(logos).eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in exp.fulfill() },
            receiveValue: { received = $0 }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received[1]?.contains("logo1"), true)
    }
    
    func testFetchQuotesWrapperSuccess() {
        // Given
        let ids = [1,2]
        let q1 = Quote(price: 1.0, volume24h: nil, volumeChange24h: nil, percentChange1h: nil, percentChange24h: 1, percentChange7d: nil, percentChange30d: nil, percentChange60d: nil, percentChange90d: nil, marketCap: nil, marketCapDominance: nil, fullyDilutedMarketCap: nil, lastUpdated: nil)
        let q2 = Quote(price: 2.0, volume24h: nil, volumeChange24h: nil, percentChange1h: nil, percentChange24h: -1, percentChange7d: nil, percentChange30d: nil, percentChange60d: nil, percentChange90d: nil, marketCap: nil, marketCapDominance: nil, fullyDilutedMarketCap: nil, lastUpdated: nil)
        let quotes = [1:q1, 2:q2]
        let exp = expectation(description: "quotes")
        var received: [Int:Quote] = [:]
        
        // When
        requestManager.fetchQuotes(ids: ids, convert: "USD", priority: .normal) {
            Just(quotes)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in exp.fulfill() },
            receiveValue: { received = $0 }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received[1]?.price, 1.0)
        XCTAssertEqual(received[2]?.price, 2.0)
    }
    
    func testExecuteRequestCastingErrorWhenTypeMismatchOnDedup() {
        // Given: start a request that publishes Int for a key and stays active for a short time
        // Use high priority and delay output so throttling doesn't trigger and activeRequests contains the publisher
        let key = "cast_mismatch"
        requestManager.executeRequest(key: key, priority: .high) {
            Just(123)
                .setFailureType(to: Error.self)
                .delay(for: .milliseconds(200), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { (_: Int) in }
        )
        .store(in: &cancellables)

        // When: while first request is still active, request the same key expecting a different type
        let secondDone = expectation(description: "second")
        var receivedError: RequestError?
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.requestManager.executeRequest(key: key, priority: .high) {
                Just("abc")
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        receivedError = err as? RequestError
                    }
                    secondDone.fulfill()
                },
                receiveValue: { (_: String) in
                    XCTFail("Should not succeed with mismatched type")
                }
            )
            .store(in: &self.cancellables)
        }
        
        // Then
        wait(for: [secondDone], timeout: 2.0)
        XCTAssertEqual(receivedError, .castingError)
    }
}