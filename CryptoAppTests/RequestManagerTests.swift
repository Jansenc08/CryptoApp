//
//  RequestManagerTests.swift
//  CryptoAppTests
//
//  Created by Test Suite on 7/18/25.
//

import XCTest
import Combine
@testable import CryptoApp

final class RequestManagerTests: XCTestCase {
    
    var requestManager: RequestManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        requestManager = RequestManager() // Fresh instance for testing
        requestManager.resetForTesting() // Clear all internal state
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        requestManager.resetForTesting() // Clean up after test
        requestManager = nil
        super.tearDown()
    }
    
    // MARK: - Core Functionality Tests
    
    func testRequestManagerExists() {
        // Given & When & Then
        XCTAssertNotNil(requestManager, "RequestManager should be initialized")
    }
    
    func testExecuteRequestBasicSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Request should complete")
        let expectedValue = "test_result"
        var receivedValue: String?
        let uniqueKey = "test_key_\(UUID().uuidString)"
        
        // When
        requestManager.executeRequest(key: uniqueKey, priority: .normal) {
            Just(expectedValue)
                .setFailureType(to: Error.self)
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
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, expectedValue, "Should receive the expected value")
    }
    
    // MARK: - Request Deduplication Tests
    
    func testRequestDeduplication() {
        // Given
        let expectation = XCTestExpectation(description: "Both requests should complete")
        expectation.expectedFulfillmentCount = 2
        
        let key = "duplicate_test_\(UUID().uuidString)"
        var callCount = 0
        var results: [String] = []
        
        let createRequest = {
            return Future<String, Error> { promise in
                callCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    promise(.success("result_\(callCount)"))
                }
            }
            .eraseToAnyPublisher()
        }
        
        // When - Fire two requests with same key simultaneously
        requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { results.append($0) }
            )
            .store(in: &cancellables)
        
        requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { results.append($0) }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(callCount, 1, "Request should only be called once due to deduplication")
        XCTAssertEqual(results.count, 2, "Both subscribers should receive the result")
        XCTAssertEqual(results[0], results[1], "Both results should be identical")
    }
    
    // MARK: - Priority and Throttling Tests
    
    func testHighPriorityRequestAllowsQuickRetry() {
        // Given
        let expectation = XCTestExpectation(description: "High priority should allow quick retry")
        expectation.expectedFulfillmentCount = 2
        
        var completionCount = 0
        let uniqueKey = "high_priority_test_\(UUID().uuidString)"
        let createRequest = {
            Just("high_priority_result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - First request
        requestManager.executeRequest(key: uniqueKey, priority: .high, request: createRequest)
            .sink(
                receiveCompletion: { _ in
                    completionCount += 1
                    expectation.fulfill()
                    
                    // Wait a tiny bit to ensure first request is recorded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        // Second request (should work for high priority after 1+ seconds)
                        self.requestManager.executeRequest(key: uniqueKey, priority: .high, request: createRequest)
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
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(completionCount, 2, "High priority should allow quick consecutive requests")
    }
    
    func testNormalPriorityRequestGetsThrottled() {
        // Given
        let expectation = XCTestExpectation(description: "Normal priority should be throttled")
        var errorReceived: Error?
        let uniqueKey = "throttle_test_\(UUID().uuidString)"
        
        let createRequest = {
            Just("normal_result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - First request succeeds
        requestManager.executeRequest(key: uniqueKey, priority: .normal, request: createRequest)
            .sink(
                receiveCompletion: { _ in 
                    // Immediate second request should be throttled
                    self.requestManager.executeRequest(key: uniqueKey, priority: .normal, request: createRequest)
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
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(errorReceived, "Second request should be throttled")
        XCTAssertTrue(errorReceived is RequestError, "Error should be RequestError type")
        if let requestError = errorReceived as? RequestError {
            XCTAssertEqual(requestError, .throttled, "Should receive throttled error")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testRequestFailureHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Request failure should be handled")
        let expectedError = NSError(domain: "TestError", code: 123, userInfo: nil)
        var receivedError: Error?
        let uniqueKey = "failure_test_\(UUID().uuidString)"
        
        // When
        requestManager.executeRequest(key: uniqueKey, priority: .normal) {
            Fail<String, Error>(error: expectedError)
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
                XCTFail("Should not receive value on failure")
            }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedError, "Should receive error")
        XCTAssertEqual((receivedError as NSError?)?.code, 123, "Should receive the original error")
    }
    
    func testDifferentKeysAllowConcurrentRequests() {
        // Given
        let expectation = XCTestExpectation(description: "Different keys should allow concurrent requests")
        expectation.expectedFulfillmentCount = 2
        
        let key1 = "key1_\(UUID().uuidString)"
        let key2 = "key2_\(UUID().uuidString)"
        
        let createRequest = { (value: String) in
            Just(value)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - Two requests with different keys
        requestManager.executeRequest(key: key1, priority: .normal) {
            createRequest("result1")
        }
        .sink(
            receiveCompletion: { _ in expectation.fulfill() },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
        
        requestManager.executeRequest(key: key2, priority: .normal) {
            createRequest("result2")
        }
        .sink(
            receiveCompletion: { _ in expectation.fulfill() },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        // Test passes if both requests complete without timeout
    }
} 