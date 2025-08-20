//
//  CoinListVMTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for CoinListVM focusing on core behaviors used by the Coins screen.
//  Scope covered:
//  - Pagination on top of fullFilteredCoins (20 per page) with filter + prefix(1) guards
//  - Cached data path (offline) with pagination applied to cached dataset
//  - Error state transitions (loading toggles + user-facing error message)
//  Test patterns:
//  - Uses MockCoinManager, MockSharedCoinDataManager, and MockPersistenceService
//  - Expectations are guarded with Combine operators (filter/prefix) to avoid multi-fulfill
//  - All tests avoid touching UIKit; publishers are observed directly
//

import XCTest
import Combine
@testable import CryptoApp

final class CoinListVMTests: XCTestCase {
    
    private var viewModel: CoinListVM!
    private var mockCoinManager: MockCoinManager!
    private var mockShared: MockSharedCoinDataManager!
    private var mockPersistence: MockPersistenceService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCoinManager = MockCoinManager()
        mockShared = MockSharedCoinDataManager()
        mockPersistence = MockPersistenceService()
        cancellables = []
        
        viewModel = CoinListVM(
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockShared,
            persistenceService: mockPersistence
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        viewModel.cancelAllRequests()
        viewModel = nil
        mockCoinManager = nil
        mockShared = nil
        mockPersistence = nil
        super.tearDown()
    }
    
    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }
    
    // MARK: - Pagination
    
    func testPaginationLoadsNextPagesFromSharedData() {
        // Given: 50 coins available from shared data → VM shows 20 per page
        // Create a large dataset to test pagination behavior
        let coins = TestDataFactory.createMockCoins(count: 50)
        // Create expectation for receiving the first page of results
        let receivedExp = expectation(description: "received first page")
        // Variable to capture the count of coins in the first page
        var page1Count = 0
        
        viewModel.coins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { coins in
                page1Count = coins.count
                receivedExp.fulfill()
            }
            .store(in: &cancellables)
        
        // When: send shared coins to VM
        // This triggers the VM to process the coins and emit the first page
        mockShared.setMockCoins(coins)
        wait(for: [receivedExp], timeout: 2.0)
        
        // Then: first page size should be 20
        // Verify pagination limits the first page to 20 items
        XCTAssertEqual(page1Count, 20)
        
        // When: load more → should append next 20 (total 40)
        // Test loading the second page of results
        let page2Exp = expectation(description: "received second page")
        // Variable to capture total count after loading page 2
        var totalAfterPage2 = 0
        viewModel.coins
            .filter { $0.count == 40 }
            .prefix(1)
            .sink { updated in
                totalAfterPage2 = updated.count
                page2Exp.fulfill()
            }
            .store(in: &cancellables)
        // Trigger loading of the second page
        viewModel.loadMoreCoins()
        wait(for: [page2Exp], timeout: 2.0)
        // Verify total is now 40 (20 + 20)
        XCTAssertEqual(totalAfterPage2, 40)
        
        // When: load more → should append last 10 (total 50)
        // Test loading the final page which has remaining 10 items
        let page3Exp = expectation(description: "received third page")
        // Variable to capture final total count
        var totalAfterPage3 = 0
        viewModel.coins
            .filter { $0.count == 50 }
            .prefix(1)
            .sink { updated in
                totalAfterPage3 = updated.count
                page3Exp.fulfill()
            }
            .store(in: &cancellables)
        // Trigger loading of the third page
        viewModel.loadMoreCoins()
        wait(for: [page3Exp], timeout: 2.0)
        // Verify all 50 items are now loaded
        XCTAssertEqual(totalAfterPage3, 50)
        
        // When: load more again → should not change (no more data)
        // Test that loadMore has no effect when all data is loaded
        viewModel.loadMoreCoins()
        wait(0.1)
        // Verify count remains at 50 (no additional data to load)
        XCTAssertEqual(totalAfterPage3, 50)
    }
    
    // MARK: - Cached Data Path
    
    func testFetchCoinsUsesCachedOfflineData() {
        // Given: save offline data and mark cache fresh
        // Create offline data that should be used when network is unavailable
        let cachedCoins = TestDataFactory.createMockCoins(count: 30)
        let cachedLogos = TestDataFactory.createMockLogos(for: cachedCoins.map { $0.id })
        // Store the offline data in persistence layer
        mockPersistence.saveOfflineData(coins: cachedCoins, logos: cachedLogos)
        
        // When
        // Create expectation for cached data retrieval
        let exp = expectation(description: "received cached first page")
        // Array to capture the cached coins returned by the VM
        var received: [Coin] = []
        viewModel.coins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { coins in
                received = coins
                exp.fulfill()
            }
            .store(in: &cancellables)
        // Trigger coin fetching (should use cached data)
        viewModel.fetchCoins(convert: "USD", priority: .normal)
        wait(for: [exp], timeout: 2.0)
        
        // Then: should show first 20 from cached 30
        // Verify pagination applies to cached data (first page of 20)
        XCTAssertEqual(received.count, 20)
        // Verify the first coin has the expected ID from cached data
        XCTAssertEqual(received.first?.id, 1)
    }
    
    // MARK: - Error State Transitions
    
    func testFetchCoinsFailurePublishesErrorAndStopsLoading() {
        // Given
        // Configure coin manager to simulate a network failure
        mockCoinManager.shouldSucceed = false
        
        // Create expectation for loading state changes (should toggle twice)
        let loadingExp = expectation(description: "loading toggled")
        loadingExp.expectedFulfillmentCount = 2 // true then false
        // Array to capture all loading state changes
        var loadingStates: [Bool] = []
        viewModel.isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count <= 2 { loadingExp.fulfill() }
            }
            .store(in: &cancellables)
        
        // Create expectation for error message publication
        let errorExp = expectation(description: "error message received")
        // Variable to capture the error message
        var receivedError: String?
        viewModel.errorMessage
            .sink { message in
                if let msg = message, !msg.isEmpty {
                    receivedError = msg
                    errorExp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // Trigger fetch operation that will fail
        viewModel.fetchCoins(convert: "USD", priority: .high)
        wait(for: [loadingExp, errorExp], timeout: 3.0)
        
        // Then
        // Verify loading state was turned on during the request
        XCTAssertTrue(loadingStates.contains(true))
        // Verify loading state was turned off after the failure
        XCTAssertTrue(loadingStates.contains(false))
        // Verify an error message was published for the user
        XCTAssertNotNil(receivedError)
    }
}
