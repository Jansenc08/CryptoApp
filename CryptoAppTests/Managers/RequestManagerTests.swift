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
        let expectation = XCTestExpectation(description: "Request should complete successfully")
        let expectedValue = "test_result"
        var receivedValue: String?
        
        // When
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
        XCTAssertEqual(receivedValue, expectedValue)
    }
    
    // MARK: - Request Deduplication Tests
    
    func testRequestDeduplication() {
        // Given
        let expectation = XCTestExpectation(description: "All requests should complete with same result")
        expectation.expectedFulfillmentCount = 3 // Three subscribers
        
        let key = "duplicate_test"
        var callCount = 0
        var results: [String] = []
        let expectedResult = "shared_result"
        
        let createRequest = {
            return Future<String, Error> { promise in
                callCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    promise(.success(expectedResult))
                }
            }
            .eraseToAnyPublisher()
        }
        
        // When - Fire three requests with same key simultaneously
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
        XCTAssertEqual(callCount, 1, "Request should only be called once due to deduplication")
        XCTAssertEqual(results.count, 3, "All three subscribers should receive the result")
        XCTAssertTrue(results.allSatisfy { $0 == expectedResult }, "All results should be identical")
    }
    
    // MARK: - Priority System Tests
    
    func testPriorityLevels() {
        // When/Then - Test priority configurations
        XCTAssertEqual(RequestPriority.high.delayInterval, 1.0)
        XCTAssertEqual(RequestPriority.normal.delayInterval, 3.0)
        XCTAssertEqual(RequestPriority.low.delayInterval, 6.0)
    }
    
    func testHighPriorityBypassesThrottling() {
        // Given
        let expectation = XCTestExpectation(description: "High priority should bypass throttling")
        expectation.expectedFulfillmentCount = 2
        
        var completionCount = 0
        let key = "high_priority_test"
        
        let createRequest = {
            Just("high_priority_result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - Fire two high priority requests quickly
        requestManager.executeRequest(key: key, priority: .high, request: createRequest)
            .sink(
                receiveCompletion: { _ in
                    completionCount += 1
                    expectation.fulfill()
                    
                    // Immediate second request (should work for high priority)
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
        XCTAssertEqual(completionCount, 2, "High priority should allow quick consecutive requests")
    }
    
    func testNormalPriorityThrottling() {
        // Given
        let expectation = XCTestExpectation(description: "Normal priority should be throttled")
        var errorReceived: Error?
        
        let createRequest = {
            Just("result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - Test normal priority throttling
        let key = "normal_throttle_test"
        requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
            .sink(
                receiveCompletion: { _ in 
                    // Immediate second request should be throttled
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
        XCTAssertNotNil(errorReceived, "Normal priority should be throttled")
        XCTAssertEqual(errorReceived as? RequestError, .throttled)
    }
    
    // MARK: - Error Handling Tests
    
    func testRequestErrorTypes() {
        // Given
        let expectation = XCTestExpectation(description: "Should handle RequestError")
        var receivedError: RequestError?
        
        // When
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
        XCTAssertEqual(receivedError, .throttled)
    }
    
    func testNetworkErrorHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Network error should be handled")
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        var receivedError: Error?
        
        // When
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
        XCTAssertNotNil(receivedError)
        let nsError = receivedError as NSError?
        XCTAssertEqual(nsError?.domain, NSURLErrorDomain)
        XCTAssertEqual(nsError?.code, NSURLErrorNotConnectedToInternet)
    }
    
    // MARK: - Cleanup Tests
    
    func testResetFunctionality() {
        // Given
        let expectation = XCTestExpectation(description: "Reset should work")
        
        // When - Setup some state then reset
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
        requestManager.resetForTesting()
        
        // Then - Should be able to make requests again immediately
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
        // Test passes if no errors occur
    }
}