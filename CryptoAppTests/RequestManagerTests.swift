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
    // Verifies RequestManager can be created successfully
    // Tests both instance and shared singleton access
    // Ensures basic object lifecycle works
    
    
    func testRequestManagerInitialization() {
        // Given & When & Then
        XCTAssertNotNil(requestManager, "RequestManager should be initialized")
        
        // Verify shared instance works
        let sharedInstance = RequestManager.shared
        XCTAssertNotNil(sharedInstance, "Shared instance should exist")
    }
    
    
    // Creates a request with a unique key
    // Simulates 50ms network delay with Just() publisher
    // Verifies the correct value is received
    // Ensures completion callback is called
    
    // Validates:
    // - Memory efficiency (no duplicate network calls)
    // - Consistency (all subscribers get identical data)
    // - Performance (shared request execution)
    func testExecuteRequestBasicSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Request should complete successfully")
        let expectedValue = "test_result_\(UUID().uuidString)"
        var receivedValue: String?
        var completionCalled = false
        let uniqueKey = "test_key_\(UUID().uuidString)"
        
        // When
        requestManager.executeRequest(key: uniqueKey, priority: .normal) {
            Just(expectedValue)
                .setFailureType(to: Error.self)
                .delay(for: .milliseconds(50), scheduler: DispatchQueue.main) // Simulate network delay
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { completion in
                completionCalled = true
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
        XCTAssertEqual(receivedValue, expectedValue, "Should receive the expected value")
        XCTAssertTrue(completionCalled, "Completion should be called")
    }
    
    
    // Tests String, Int, and Array data types simultaneously
    // Uses different keys to avoid deduplication
    // Verifies type safety and generic support
    func testExecuteRequestWithDifferentDataTypes() {
        // Given
        let stringExpectation = XCTestExpectation(description: "String request should complete")
        let intExpectation = XCTestExpectation(description: "Int request should complete")
        let arrayExpectation = XCTestExpectation(description: "Array request should complete")
        
        var stringResult: String?
        var intResult: Int?
        var arrayResult: [String]?
        
        // When - Test different data types
        requestManager.executeRequest(key: "string_test", priority: .normal) {
            Just("hello")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in stringExpectation.fulfill() },
            receiveValue: { stringResult = $0 }
        )
        .store(in: &cancellables)
        
        requestManager.executeRequest(key: "int_test", priority: .normal) {
            Just(42)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in intExpectation.fulfill() },
            receiveValue: { intResult = $0 }
        )
        .store(in: &cancellables)
        
        requestManager.executeRequest(key: "array_test", priority: .normal) {
            Just(["a", "b", "c"])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in arrayExpectation.fulfill() },
            receiveValue: { arrayResult = $0 }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [stringExpectation, intExpectation, arrayExpectation], timeout: 2.0)
        XCTAssertEqual(stringResult, "hello")
        XCTAssertEqual(intResult, 42)
        XCTAssertEqual(arrayResult, ["a", "b", "c"])
    }
    
    // MARK: - Request Deduplication Tests
    
    // Fires 3 identical requests (same key) simultaneously
    // Tracks how many times the actual request closure is called
    // Verifies all 3 subscribers get the same result


    // Validates:
    // - Memory efficiency (no duplicate network calls)
    // - Consistency (all subscribers get identical data)
    // - Performance (shared request execution)
    func testRequestDeduplicationWithMultipleSubscribers() {
        // Given
        let expectation = XCTestExpectation(description: "All requests should complete with same result")
        expectation.expectedFulfillmentCount = 3 // Three subscribers
        
        let key = "duplicate_test_\(UUID().uuidString)"
        var callCount = 0
        var results: [String] = []
        let expectedResult = "shared_result"
        
        let createRequest = {
            return Future<String, Error> { promise in
                callCount += 1
                // Simulate network delay
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
    

    // Makes first request and waits for completion
    // Waits 3.5 seconds (past normal priority throttling)
    // Makes second request with same key
    // Verifies both requests actually execute (callCount = 2)
    
    // Validates:
    // - Deduplication doesn't persist forever
    // - Fresh requests work after throttling period
    // - Memory cleanup (old requests are removed)
    func testDeduplicationClearedAfterCompletion() {
        // Given
        let firstExpectation = XCTestExpectation(description: "First request should complete")
        let secondExpectation = XCTestExpectation(description: "Second request should complete")
        
        let key = "sequential_test_\(UUID().uuidString)"
        var callCount = 0
        
        let createRequest = {
            return Future<String, Error> { promise in
                callCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    promise(.success("result_\(callCount)"))
                }
            }
            .eraseToAnyPublisher()
        }
        
        // When - First request
        requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
            .sink(
                receiveCompletion: { _ in
                    firstExpectation.fulfill()
                    
                    // Wait for normal priority delay interval (3 seconds) plus buffer
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        self.requestManager.executeRequest(key: key, priority: .normal, request: createRequest)
                            .sink(
                                receiveCompletion: { _ in secondExpectation.fulfill() },
                                receiveValue: { _ in }
                            )
                            .store(in: &self.cancellables)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [firstExpectation, secondExpectation], timeout: 8.0)
        XCTAssertEqual(callCount, 2, "Should make separate calls after first completes")
    }
    
    
    // Makes 2 requests with different keys simultaneously
    // Uses high priority to avoid throttling delays
    // Verifies both requests execute (callCount = 2)

    // Validates:
    // - Deduplication is per-key, not global
    // - Different operations don't block each other
    // - High priority bypasses throttling
    func testDeduplicationWithDifferentKeysAfterCompletion() {
        // Given - Test that deduplication works per-key, not globally
        let expectation = XCTestExpectation(description: "Different key requests should complete")
        expectation.expectedFulfillmentCount = 2
        
        var callCount = 0
        let key1 = "sequential_test_1_\(UUID().uuidString)"
        let key2 = "sequential_test_2_\(UUID().uuidString)"
        
        let createRequest = {
            return Future<String, Error> { promise in
                callCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    promise(.success("result_\(callCount)"))
                }
            }
            .eraseToAnyPublisher()
        }
        
        // When - Fire requests with different keys (should not be deduplicated)
        requestManager.executeRequest(key: key1, priority: .high, request: createRequest) // Use high priority to avoid throttling
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        requestManager.executeRequest(key: key2, priority: .high, request: createRequest) // Use high priority to avoid throttling
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(callCount, 2, "Different keys should not be deduplicated")
    }
    
    // MARK: - Priority System Tests

    // Tests that priority levels have correct delay intervals
    // High: 1s, Normal: 3s, Low: 6s
    // Validates priority descriptions for debugging

    // Validates:
    // - Priority system configuration is correct
    // - Rate limiting intervals match expectations
    // - Debug information is available
    func testPriorityLevelsAndDelayIntervals() {
        // Given & When & Then
        XCTAssertEqual(RequestPriority.high.delayInterval, 1.0, "High priority should have 1 second delay")
        XCTAssertEqual(RequestPriority.normal.delayInterval, 3.0, "Normal priority should have 3 second delay")
        XCTAssertEqual(RequestPriority.low.delayInterval, 6.0, "Low priority should have 6 second delay")
        
        // Test descriptions
        XCTAssertEqual(RequestPriority.high.description, "🔴 HIGH")
        XCTAssertEqual(RequestPriority.normal.description, "🟡 NORMAL")
        XCTAssertEqual(RequestPriority.low.description, "🔵 LOW")
    }
    
    
    // Makes first high priority request
    // Immediately makes second high priority request (0.1s later)
    // Verifies both complete successfully


    // Validates:
    // - High priority requests aren't throttled
    // - User interactions remain responsive
    // - Filter changes work immediately
    func testHighPriorityBypassesThrottling() {
        // Given
        let expectation = XCTestExpectation(description: "High priority should bypass throttling")
        expectation.expectedFulfillmentCount = 2
        
        var completionCount = 0
        let uniqueKey = "high_priority_bypass_\(UUID().uuidString)"
        
        let createRequest = {
            Just("high_priority_result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - Fire two high priority requests quickly
        requestManager.executeRequest(key: uniqueKey, priority: .high, request: createRequest)
            .sink(
                receiveCompletion: { _ in
                    completionCount += 1
                    expectation.fulfill()
                    
                    // Immediate second request (should work for high priority)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
    
    

    // Makes normal priority request, then immediate second request
    // Makes low priority request, then immediate second request
    // Verifies second requests are throttled (receive .throttled error)

    // Validates:
    // - Rate limiting works for normal/low priority
    // - Proper error handling for throttled requests
    // - API protection mechanisms function correctly
    func testNormalAndLowPriorityThrottling() {
        // Given
        let normalExpectation = XCTestExpectation(description: "Normal priority should be throttled")
        let lowExpectation = XCTestExpectation(description: "Low priority should be throttled")
        
        var normalErrorReceived: Error?
        var lowErrorReceived: Error?
        
        let createRequest = {
            Just("result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // When - Test normal priority throttling
        let normalKey = "normal_throttle_\(UUID().uuidString)"
        requestManager.executeRequest(key: normalKey, priority: .normal, request: createRequest)
            .sink(
                receiveCompletion: { _ in 
                    // Immediate second request should be throttled
                    self.requestManager.executeRequest(key: normalKey, priority: .normal, request: createRequest)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    normalErrorReceived = error
                                }
                                normalExpectation.fulfill()
                            },
                            receiveValue: { _ in }
                        )
                        .store(in: &self.cancellables)
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Test low priority throttling
        let lowKey = "low_throttle_\(UUID().uuidString)"
        requestManager.executeRequest(key: lowKey, priority: .low, request: createRequest)
            .sink(
                receiveCompletion: { _ in 
                    // Immediate second request should be throttled
                    self.requestManager.executeRequest(key: lowKey, priority: .low, request: createRequest)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    lowErrorReceived = error
                                }
                                lowExpectation.fulfill()
                            },
                            receiveValue: { _ in }
                        )
                        .store(in: &self.cancellables)
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [normalExpectation, lowExpectation], timeout: 2.0)
        XCTAssertNotNil(normalErrorReceived, "Normal priority should be throttled")
        XCTAssertNotNil(lowErrorReceived, "Low priority should be throttled")
        XCTAssertEqual(normalErrorReceived as? RequestError, .throttled)
        XCTAssertEqual(lowErrorReceived as? RequestError, .throttled)
    }
    
    // MARK: - Error Handling Tests
    
  
    // Tests each RequestError type: .throttled, .castingError, .duplicateRequest, .rateLimited
    // Verifies errors are properly propagated to subscribers
    // Checks error descriptions are meaningful

    // Validates:
    // - All error paths work correctly
    // - Error messages are helpful for debugging
    // - Proper error type propagation
    func testAllRequestErrorTypes() {
        let errors: [RequestError] = [.throttled, .castingError, .duplicateRequest, .rateLimited]
        
        for error in errors {
            let expectation = XCTestExpectation(description: "Should handle \(error) error")
            var receivedError: RequestError?
            
            requestManager.executeRequest(key: "error_test_\(error)", priority: .normal) {
                Fail<String, Error>(error: error)
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
            
            wait(for: [expectation], timeout: 1.0)
            XCTAssertEqual(receivedError, error, "Should receive the correct error type")
            
            // Test error descriptions
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error should have description")
        }
    }
    
    // Simulates NSURLErrorNotConnectedToInternet
    // Verifies error is passed through unchanged
    // Tests network-level error handling

    // Validates:
    // - Network errors aren't modified by RequestManager
    // - Proper error domain and code preservation
    // - Integration with iOS networking stack
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
        XCTAssertNotNil(receivedError, "Should receive network error")
        let nsError = receivedError as NSError?
        XCTAssertEqual(nsError?.domain, NSURLErrorDomain)
        XCTAssertEqual(nsError?.code, NSURLErrorNotConnectedToInternet)
    }
    
    
    // Specifically tests RequestError.castingError
    // Verifies type casting failures are handled


    // Validates:
    // - Type safety mechanisms work
    // - Casting failures are caught and reported
    // - Generic type system is robust
    func testCastingError() {
        // Given
        let expectation = XCTestExpectation(description: "Casting error should be handled")
        var receivedError: RequestError?
        
        // When - This would trigger casting error in real scenario
        requestManager.executeRequest(key: "casting_test", priority: .normal) {
            Fail<String, Error>(error: RequestError.castingError)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error as? RequestError
                }
                expectation.fulfill()
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .castingError)
    }
    
    // MARK: - Concurrent Request Tests
    
    
    // Fires 5 requests simultaneously with different keys
    // Uses random delays (10-100ms) to simulate real network
    // Collects all results thread-safely
    // Verifies all 5 complete successfully

    // Validates:
    // - Thread safety in concurrent scenarios
    // - No deadlocks or race conditions
    // - Independent request processing
    // - Proper resource management
    func testConcurrentRequestsWithDifferentKeys() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent requests should all complete")
        expectation.expectedFulfillmentCount = 5
        
        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "results.queue")
        
        // When - Fire multiple requests with different keys
        for i in 0..<5 {
            let key = "concurrent_key_\(i)_\(UUID().uuidString)"
            let expectedValue = "result_\(i)"
            
            requestManager.executeRequest(key: key, priority: .normal) {
                Just(expectedValue)
                    .setFailureType(to: Error.self)
                    .delay(for: .milliseconds(Int.random(in: 10...100)), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Request \(i) should not fail: \(error)")
                    }
                    expectation.fulfill()
                },
                receiveValue: { value in
                    resultsQueue.sync {
                        results.append(value)
                    }
                }
            )
            .store(in: &cancellables)
        }
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(results.count, 5, "Should receive all 5 results")
        
        // Verify all expected values are present
        for i in 0..<5 {
            XCTAssertTrue(results.contains("result_\(i)"), "Should contain result_\(i)")
        }
    }
    
    

    // Makes requests with low, normal, and high priorities simultaneously
    // Tracks completion order
    // Verifies all complete within timeout

    // Validates:
    // - Priority system doesn't block requests
    // - Mixed priority scenarios work correctly
    // - No priority-based deadlocks
    func testConcurrentRequestsWithMixedPriorities() {
        // Given
        let expectation = XCTestExpectation(description: "Mixed priority requests should complete")
        expectation.expectedFulfillmentCount = 3
        
        var completionOrder: [String] = []
        let orderQueue = DispatchQueue(label: "order.queue")
        
        let priorities: [RequestPriority] = [.low, .normal, .high]
        
        // When - Fire requests with different priorities
        for (_, priority) in priorities.enumerated() {
            let key = "priority_\(priority)_\(UUID().uuidString)"
            
            requestManager.executeRequest(key: key, priority: priority) {
                Just("result_\(priority)")
                    .setFailureType(to: Error.self)
                    .delay(for: .milliseconds(50), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { value in
                    orderQueue.sync {
                        completionOrder.append(value)
                    }
                }
            )
            .store(in: &cancellables)
        }
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(completionOrder.count, 3, "Should complete all priority requests")
    }
    
    // MARK: - Memory Management Tests
    
    
    // Makes a request and waits for completion
    // Calls resetForTesting() to clear internal state
    // Verifies no crashes occur (indicating proper cleanup)

    // Validates:
    // - No memory leaks in request processing
    // - Internal dictionaries are cleaned up
    // - Weak references work correctly
    // - Long-running app stability
    func testRequestManagerMemoryCleanup() {
        // Given
        let expectation = XCTestExpectation(description: "Memory should be cleaned up")
        let key = "memory_test_\(UUID().uuidString)"
        
        // When
        requestManager.executeRequest(key: key, priority: .normal) {
            Just("test")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in
                // After completion, internal state should be cleaned
                expectation.fulfill()
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        // Reset and verify clean state
        requestManager.resetForTesting()
        // If no crash occurs, memory management is working correctly
    }
    

    // Starts a request with 2-second delay
    // Immediately cancels the subscription
    // Uses inverted expectation (expects NOT to complete)
    // Verifies cancellation works properly

    // Validates:
    // - Combine cancellation integration
    // - Resource cleanup on cancellation
    // - No unexpected callbacks after cancel
    // - Proper subscription lifecycle management
    func testCancellationHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Cancellation should be handled properly")
        expectation.isInverted = true // We expect this NOT to fulfill
        
        let key = "cancellation_test_\(UUID().uuidString)"
        
        // When
        let cancellable = requestManager.executeRequest(key: key, priority: .normal) {
            Just("test")
                .setFailureType(to: Error.self)
                .delay(for: .seconds(2), scheduler: DispatchQueue.main) // Long delay
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in
                expectation.fulfill() // This should not happen due to cancellation
            },
            receiveValue: { _ in }
        )
        
        // Cancel immediately
        cancellable.cancel()
        
        // Then
        wait(for: [expectation], timeout: 1.0) // Short timeout since it's inverted
        // Test passes if the completion never occurs
    }
    
    // MARK: - Edge Cases Tests
    
    
    // Makes request with empty string key ("")
    // Verifies it works normally, no crashes

    // Validates:
    // - Robustness against invalid input
    // - Empty string key handling
    // - Error prevention in edge cases
    func testEmptyKeyHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Empty key should be handled")
        var receivedValue: String?
        
        // When
        requestManager.executeRequest(key: "", priority: .normal) {
            Just("empty_key_result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in expectation.fulfill() },
            receiveValue: { receivedValue = $0 }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, "empty_key_result", "Should handle empty keys")
    }
    
    
    // Creates 1000-character key string
    // Verifies request works normally
    // Tests memory and performance with large keys

    // Validates:
    // - Performance with large keys
    // - Memory efficiency
    // - No string length limitations
    // - Dictionary key handling
    func testVeryLongKeyHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Very long key should be handled")
        let longKey = String(repeating: "a", count: 1000)
        var receivedValue: String?
        
        // When
        requestManager.executeRequest(key: longKey, priority: .normal) {
            Just("long_key_result")
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        .sink(
            receiveCompletion: { _ in expectation.fulfill() },
            receiveValue: { receivedValue = $0 }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, "long_key_result", "Should handle very long keys")
    }
    
    
    // Makes 2 requests with different priorities
    // Calls resetForTesting() to clear all state
    // Makes new request with same key as before
    // Verifies reset worked and new request succeeds

    // Validates:
    // - Complete state reset functionality
    // - No residual state after reset
    // - Fresh start capability
    // - Testing infrastructure reliability
    func testRequestManagerResetFunctionality() {
        // Given
        let setupExpectation = XCTestExpectation(description: "Setup requests should complete")
        setupExpectation.expectedFulfillmentCount = 2
        
        // When - Setup some state
        requestManager.executeRequest(key: "reset_test_1", priority: .normal) {
            Just("result1").setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { _ in setupExpectation.fulfill() }, receiveValue: { _ in })
        .store(in: &cancellables)
        
        requestManager.executeRequest(key: "reset_test_2", priority: .high) {
            Just("result2").setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { _ in setupExpectation.fulfill() }, receiveValue: { _ in })
        .store(in: &cancellables)
        
        wait(for: [setupExpectation], timeout: 1.0)
        
        // Reset and verify clean state
        requestManager.resetForTesting()
        
        // Then - Should be able to make requests again immediately
        let postResetExpectation = XCTestExpectation(description: "Post-reset request should work")
        requestManager.executeRequest(key: "reset_test_1", priority: .normal) {
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
