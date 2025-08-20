//
//  WatchlistManagerTests.swift
//  CryptoAppTests
//
//

import XCTest
import CoreData
@testable import CryptoApp

final class WatchlistManagerTests: XCTestCase {
    
    // MARK: - In-memory Core Data Stack (Test Helpers)
    
    private final class InMemoryCoreDataStack {
        let managedObjectModel: NSManagedObjectModel
        let persistentStoreCoordinator: NSPersistentStoreCoordinator
        
        init?(modelName: String = "WatchlistModel") {
            // Load model from the app bundle (contains WatchlistItem)
            let bundle = Bundle(for: WatchlistItem.self)
            guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") ??
                                  bundle.url(forResource: modelName, withExtension: "mom"),
                  let model = NSManagedObjectModel(contentsOf: modelURL) else {
                return nil
            }
            self.managedObjectModel = model
            self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            do {
                try persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType,
                                                                  configurationName: nil,
                                                                  at: nil,
                                                                  options: nil)
            } catch {
                return nil
            }
        }
        
        func makeContext() -> NSManagedObjectContext {
            // Use a private queue context for better test isolation and thread safety
            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = persistentStoreCoordinator
            return context
        }
        
        final class FailingContext: NSManagedObjectContext {
            override func save() throws {
                throw NSError(domain: "TestFailingContext", code: 999, userInfo: [NSLocalizedDescriptionKey: "Simulated Core Data save failure"])
            }
        }
        
        func makeFailingContext() -> NSManagedObjectContext {
            let context = FailingContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = persistentStoreCoordinator
            return context
        }
    }
    
    private final class TestCoreDataManager: CoreDataManagerProtocol {
        let context: NSManagedObjectContext
        
        init(context: NSManagedObjectContext) {
            self.context = context
        }
        
        func save() {
            // Matches production async behavior for realistic testing
            context.perform {
                if self.context.hasChanges {
                    do { 
                        try self.context.save() 
                    } catch { 
                        self.context.rollback()
                        XCTFail("Core Data save error: \(error)") 
                    }
                }
            }
        }
        
        func delete<T>(_ object: T) where T : NSManagedObject {
            // Matches production async behavior for realistic testing
            context.perform {
                self.context.delete(object)
                if self.context.hasChanges {
                    do { 
                        try self.context.save() 
                    } catch { 
                        self.context.rollback()
                        XCTFail("Core Data delete save error: \(error)") 
                    }
                }
            }
        }
        
        func fetch<T>(_ objectType: T.Type) -> [T] where T : NSManagedObject {
            let entityName = String(describing: objectType)
            let request = NSFetchRequest<T>(entityName: entityName)
            request.includesPendingChanges = false
            var results: [T] = []
            context.performAndWait {
                do { 
                    results = try context.fetch(request) 
                } catch { 
                    print("Fetch error for \(entityName): \(error)")
                    results = [] 
                }
            }
            return results
        }
        
        func fetch<T>(_ objectType: T.Type, where predicate: NSPredicate) -> [T] where T : NSManagedObject {
            let entityName = String(describing: objectType)
            let request = NSFetchRequest<T>(entityName: entityName)
            request.predicate = predicate
            request.includesPendingChanges = false
            var results: [T] = []
            context.performAndWait {
                do { 
                    results = try context.fetch(request) 
                } catch { 
                    print("Fetch error for \(entityName) with predicate: \(error)")
                    results = [] 
                }
            }
            return results
        }
        
        func fetchWatchlistItems() -> [WatchlistItem] {
            let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
            request.includesPendingChanges = false
            var results: [WatchlistItem] = []
            context.performAndWait {
                do { 
                    results = try context.fetch(request) 
                } catch { 
                    print("Fetch error for WatchlistItem: \(error)")
                    results = [] 
                }
            }
            return results
        }
        
        func fetchWatchlistItems(where predicate: NSPredicate) -> [WatchlistItem] {
            let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
            request.predicate = predicate
            request.includesPendingChanges = false
            var results: [WatchlistItem] = []
            context.performAndWait {
                do { 
                    results = try context.fetch(request) 
                } catch { 
                    print("Fetch error for WatchlistItem with predicate: \(error)")
                    results = [] 
                }
            }
            return results
        }
    }
    
    // MARK: - Properties
    
    private var stack: InMemoryCoreDataStack!
    private var coreDataManager: TestCoreDataManager!
    private var watchlistManager: WatchlistManager!
    private var coinManager: MockCoinManager!
    private var persistenceService: MockPersistenceService!
    
    // MARK: - Setup/Teardown
    
    override func setUp() {
        super.setUp()
        stack = InMemoryCoreDataStack()
        XCTAssertNotNil(stack, "Failed to create in-memory Core Data stack for tests")
        let context = stack.makeContext()
        coreDataManager = TestCoreDataManager(context: context)
        coinManager = MockCoinManager()
        persistenceService = MockPersistenceService()
        watchlistManager = WatchlistManager(coreDataManager: coreDataManager,
                                            coinManager: coinManager,
                                            persistenceService: persistenceService)
        
        // Wait for initialization to complete properly
        waitForWatchlistInitialization()
    }
    
    override func tearDown() {
        // Ensure all background operations complete before cleanup
        waitForBackgroundOperationsToComplete()
        
        // Clear watchlist first to prevent orphaned operations
        if let manager = watchlistManager {
            manager.clearWatchlist()
            wait(seconds: 0.3) // Allow clear operation to complete
        }
        
        // Nil all references
        watchlistManager = nil
        coreDataManager = nil
        coinManager = nil
        persistenceService = nil
        stack = nil
        
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    private func wait(seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }
    
    private func makeCoins(_ count: Int, startId: Int = 1) -> [Coin] {
        return (0..<count).map { i in
            TestDataFactory.createMockCoin(id: startId + i, symbol: "T\(startId + i)", name: "Test\(startId + i)", rank: startId + i)
        }
    }
    
    private func waitForWatchlistInitialization() {
        let expectation = XCTestExpectation(description: "Watchlist initialization")
        
        // Poll for initialization completion
        DispatchQueue.global().async {
            var attempts = 0
            while attempts < 50 { // Max 5 seconds (50 * 0.1)
                if self.watchlistManager.getWatchlistCount() >= 0 { // This indicates initialization is complete
                    DispatchQueue.main.async {
                        expectation.fulfill()
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 0.1)
                attempts += 1
            }
            
            DispatchQueue.main.async {
                XCTFail("Watchlist initialization timed out")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 6.0)
    }
    
    private func waitForBackgroundOperationsToComplete() {
        // Give background operations time to complete
        let expectation = XCTestExpectation(description: "Background operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    private func waitForOperationCompletion(timeout: TimeInterval = 2.0) {
        let expectation = XCTestExpectation(description: "Operation completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }
    
    // MARK: - Core Data CRUD Tests
    
    func testAddAndFetchWatchlistItem() {
        // Given
        // Create a test coin to add to the watchlist
        let coin = TestDataFactory.createMockCoin(id: 101, symbol: "AAA", name: "Alpha", rank: 1)
        
        // When
        // Add the coin to the watchlist (this should persist to Core Data)
        watchlistManager.addToWatchlist(coin)
        // Wait for the async Core Data operation to complete
        waitForOperationCompletion()
        
        // Then
        // Verify the coin is now tracked as being in the watchlist
        XCTAssertTrue(watchlistManager.isInWatchlist(coinId: 101))
        // Verify the manager's internal count matches the Core Data count
        XCTAssertEqual(watchlistManager.getWatchlistCount(), coreDataManager.fetchWatchlistItems().count)
        // Verify exactly one item was persisted to Core Data
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 1)
    }
    
    func testRemoveWatchlistItem() {
        // Given
        // Create and add a coin to establish initial state
        let coin = TestDataFactory.createMockCoin(id: 202, symbol: "BBB", name: "Beta", rank: 2)
        watchlistManager.addToWatchlist(coin)
        waitForOperationCompletion()
        // Verify the coin was successfully added before testing removal
        XCTAssertTrue(watchlistManager.isInWatchlist(coinId: 202))
        
        // When
        // Remove the coin from the watchlist by its ID
        watchlistManager.removeFromWatchlist(coinId: 202)
        // Wait for the async Core Data deletion to complete
        waitForOperationCompletion()
        
        // Then
        // Verify the coin is no longer tracked as being in the watchlist
        XCTAssertFalse(watchlistManager.isInWatchlist(coinId: 202))
        // Verify the Core Data store is now empty
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 0)
    }
    
    // MARK: - Batch Operations
    
    func testBatchAddAndRemoveWatchlistItems() {
        // Given
        // Create 5 test coins for batch operations (IDs 1000-1004)
        let coinsToAdd = makeCoins(5, startId: 1000)
        
        // When - Batch add
        // Add all 5 coins to the watchlist in a single batch operation
        watchlistManager.addMultipleToWatchlist(coinsToAdd)
        // Wait for the batch Core Data operation to complete
        waitForOperationCompletion()
        
        // Then
        // Verify all 5 coins were persisted to Core Data
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 5)
        // Verify the manager's internal count is accurate
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 5)
        // Verify each coin is tracked as being in the watchlist
        XCTAssertTrue(coinsToAdd.allSatisfy { watchlistManager.isInWatchlist(coinId: $0.id) })
        
        // When - Batch remove subset
        // Remove 3 out of 5 coins (every other coin: 1000, 1002, 1004)
        let idsToRemove = [1000, 1002, 1004]
        watchlistManager.removeMultipleFromWatchlist(coinIds: idsToRemove)
        // Wait for the batch removal operation to complete
        waitForOperationCompletion()
        
        // Then - Remaining should be 2
        // Verify only 2 items remain in Core Data (1001, 1003)
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 2)
        // Verify the manager's count reflects the removals
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 2)
        // Verify the removed coins are no longer tracked in the watchlist
        XCTAssertFalse(idsToRemove.contains { watchlistManager.isInWatchlist(coinId: $0) })
    }
    
    func testClearWatchlist() {
        // Given
        // Create 3 test coins and add them to establish state
        let coins = makeCoins(3, startId: 2000)
        watchlistManager.addMultipleToWatchlist(coins)
        waitForOperationCompletion()
        // Verify initial state has 3 items
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 3)
        
        // When
        // Clear the entire watchlist (should remove all Core Data entries)
        watchlistManager.clearWatchlist()
        // Wait for the bulk deletion operation to complete
        waitForOperationCompletion()
        
        // Then
        // Verify the manager reports zero items
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 0)
        // Verify Core Data store is completely empty
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 0)
    }
    
    // MARK: - Rollback Scenarios
    
    func testAddRollbackOnSaveFailure() {
        // Given - Failing context
        // Create a special Core Data stack that will fail on save operations
        // This tests the optimistic update rollback mechanism
        guard let failingStack = InMemoryCoreDataStack() else { XCTFail("Failed to create failing stack"); return }
        let failingManager = TestCoreDataManager(context: failingStack.makeFailingContext())
        let failingWatchlist = WatchlistManager(coreDataManager: failingManager,
                                                coinManager: coinManager,
                                                persistenceService: persistenceService)
        
        // Wait for initialization
        // The failing watchlist manager needs to initialize before we can test rollback
        let initExpectation = XCTestExpectation(description: "Failing watchlist initialization")
        DispatchQueue.global().async {
            var attempts = 0
            while attempts < 50 {
                _ = failingWatchlist.getWatchlistCount() // forces init path
                Thread.sleep(forTimeInterval: 0.1)
                attempts += 1
            }
            DispatchQueue.main.async { initExpectation.fulfill() }
        }
        wait(for: [initExpectation], timeout: 6.0)
        
        // Create a test coin for the rollback scenario
        let coin = TestDataFactory.createMockCoin(id: 303, symbol: "CCC", name: "Gamma", rank: 3)
        
        // When
        // Attempt to add coin - this will trigger optimistic update followed by save failure
        failingWatchlist.addToWatchlist(coin)
        
        // Wait longer for rollback to occur
        // The manager should detect the save failure and rollback the optimistic update
        let rollbackExpectation = XCTestExpectation(description: "Rollback completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            rollbackExpectation.fulfill()
        }
        wait(for: [rollbackExpectation], timeout: 2.0)
        
        // Then - Should rollback optimistic update
        // Verify the coin is NOT in the watchlist (optimistic update was rolled back)
        XCTAssertFalse(failingWatchlist.isInWatchlist(coinId: 303))
        // Verify Core Data remains empty (save failure prevented persistence)
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 0)
        _ = failingWatchlist // keep alive until test completes
    }
    
    func testBatchAddRollbackOnFailure() {
        // Given - Failing context
        // Test batch add operation rollback when Core Data save fails
        // This ensures multiple optimistic updates are all rolled back together
        guard let failingStack = InMemoryCoreDataStack() else { XCTFail("Failed to create failing stack"); return }
        let failingManager = TestCoreDataManager(context: failingStack.makeFailingContext())
        let failingWatchlist = WatchlistManager(coreDataManager: failingManager,
                                                coinManager: coinManager,
                                                persistenceService: persistenceService)
        
        // Wait for initialization
        let initExpectation = XCTestExpectation(description: "Batch failing watchlist initialization")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1.0)
        
        // Create 4 test coins for batch operation testing
        let coins = makeCoins(4, startId: 4000)
        
        // When
        // Attempt batch add - all coins should be optimistically added then rolled back
        failingWatchlist.addMultipleToWatchlist(coins)
        
        // Wait longer for batch rollback to occur
        // Batch operations take slightly longer to rollback due to multiple IDs
        let rollbackExpectation = XCTestExpectation(description: "Batch rollback completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            rollbackExpectation.fulfill()
        }
        wait(for: [rollbackExpectation], timeout: 2.5)
        
        // Then - Should rollback all optimistic IDs
        // Verify Core Data remains empty (batch save failed)
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 0)
        // Verify manager reports zero count (all optimistic updates rolled back)
        XCTAssertEqual(failingWatchlist.getWatchlistCount(), 0)
        // Verify none of the coins are tracked as being in watchlist
        XCTAssertFalse(coins.contains { failingWatchlist.isInWatchlist(coinId: $0.id) })
        _ = failingWatchlist // keep alive until test completes
    }
    
    func testBatchRemoveRollbackOnFailure() {
        // Given - Shared store with items added using working context
        guard let sharedStack = InMemoryCoreDataStack() else { XCTFail("Failed to create shared stack"); return }
        let writerManager = TestCoreDataManager(context: sharedStack.makeContext())
        
        // Pre-populate store with proper Core Data context management
        let writerContext = writerManager.context
        let initialCoins = makeCoins(3, startId: 5000)
        
        writerContext.performAndWait {
            initialCoins.forEach { _ = WatchlistItem(context: writerContext, coin: $0) }
            do { 
                try writerContext.save() 
            } catch { 
                XCTFail("Prepopulation save failed: \(error)") 
            }
        }
        
        // Create failing manager sharing the same PSC
        let failingContext = InMemoryCoreDataStack.FailingContext(concurrencyType: .privateQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = sharedStack.persistentStoreCoordinator
        let failingManager = TestCoreDataManager(context: failingContext)
        let failingWatchlist = WatchlistManager(coreDataManager: failingManager,
                                                coinManager: coinManager,
                                                persistenceService: persistenceService)
        
        // Wait for initialization and verify pre-populated state
        let initExpectation = XCTestExpectation(description: "Shared store initialization")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1.5)
        
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 3)
        
        // When - Attempt failing batch remove
        let idsToRemove = initialCoins.prefix(2).map { $0.id }
        failingWatchlist.removeMultipleFromWatchlist(coinIds: idsToRemove)
        
        // Wait longer for batch remove rollback to occur
        let rollbackExpectation = XCTestExpectation(description: "Batch remove rollback completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            rollbackExpectation.fulfill()
        }
        wait(for: [rollbackExpectation], timeout: 3.0)
        
        // Then - Optimistic removal should be rolled back, DB unchanged
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 3)
        XCTAssertTrue(initialCoins.allSatisfy { failingWatchlist.isInWatchlist(coinId: $0.id) })
        _ = failingWatchlist // keep alive until test completes
    }
}


