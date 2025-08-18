//
//  CoinListVMTests.swift
//  CryptoAppTests
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
        let coins = TestDataFactory.createMockCoins(count: 50)
        let receivedExp = expectation(description: "received first page")
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
        mockShared.setMockCoins(coins)
        wait(for: [receivedExp], timeout: 2.0)
        
        // Then: first page size should be 20
        XCTAssertEqual(page1Count, 20)
        
        // When: load more → should append next 20 (total 40)
        let page2Exp = expectation(description: "received second page")
        var totalAfterPage2 = 0
        viewModel.coins
            .filter { $0.count == 40 }
            .prefix(1)
            .sink { updated in
                totalAfterPage2 = updated.count
                page2Exp.fulfill()
            }
            .store(in: &cancellables)
        viewModel.loadMoreCoins()
        wait(for: [page2Exp], timeout: 2.0)
        XCTAssertEqual(totalAfterPage2, 40)
        
        // When: load more → should append last 10 (total 50)
        let page3Exp = expectation(description: "received third page")
        var totalAfterPage3 = 0
        viewModel.coins
            .filter { $0.count == 50 }
            .prefix(1)
            .sink { updated in
                totalAfterPage3 = updated.count
                page3Exp.fulfill()
            }
            .store(in: &cancellables)
        viewModel.loadMoreCoins()
        wait(for: [page3Exp], timeout: 2.0)
        XCTAssertEqual(totalAfterPage3, 50)
        
        // When: load more again → should not change (no more data)
        viewModel.loadMoreCoins()
        wait(0.1)
        XCTAssertEqual(totalAfterPage3, 50)
    }
    
    // MARK: - Cached Data Path
    
    func testFetchCoinsUsesCachedOfflineData() {
        // Given: save offline data and mark cache fresh
        let cachedCoins = TestDataFactory.createMockCoins(count: 30)
        let cachedLogos = TestDataFactory.createMockLogos(for: cachedCoins.map { $0.id })
        mockPersistence.saveOfflineData(coins: cachedCoins, logos: cachedLogos)
        
        // When
        let exp = expectation(description: "received cached first page")
        var received: [Coin] = []
        viewModel.coins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { coins in
                received = coins
                exp.fulfill()
            }
            .store(in: &cancellables)
        viewModel.fetchCoins(convert: "USD", priority: .normal)
        wait(for: [exp], timeout: 2.0)
        
        // Then: should show first 20 from cached 30
        XCTAssertEqual(received.count, 20)
        XCTAssertEqual(received.first?.id, 1)
    }
    
    // MARK: - Error State Transitions
    
    func testFetchCoinsFailurePublishesErrorAndStopsLoading() {
        // Given
        mockCoinManager.shouldSucceed = false
        
        let loadingExp = expectation(description: "loading toggled")
        loadingExp.expectedFulfillmentCount = 2 // true then false
        var loadingStates: [Bool] = []
        viewModel.isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count <= 2 { loadingExp.fulfill() }
            }
            .store(in: &cancellables)
        
        let errorExp = expectation(description: "error message received")
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
        viewModel.fetchCoins(convert: "USD", priority: .high)
        wait(for: [loadingExp, errorExp], timeout: 3.0)
        
        // Then
        XCTAssertTrue(loadingStates.contains(true))
        XCTAssertTrue(loadingStates.contains(false))
        XCTAssertNotNil(receivedError)
    }
}
