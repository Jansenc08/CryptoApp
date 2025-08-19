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
        let coin = TestDataFactory.createMockCoin(id: 101, symbol: "AAA", name: "Alpha", rank: 1)
        
        // When
        watchlistManager.addToWatchlist(coin)
        waitForOperationCompletion()
        
        // Then
        XCTAssertTrue(watchlistManager.isInWatchlist(coinId: 101))
        XCTAssertEqual(watchlistManager.getWatchlistCount(), coreDataManager.fetchWatchlistItems().count)
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 1)
    }
    
    func testRemoveWatchlistItem() {
        // Given
        let coin = TestDataFactory.createMockCoin(id: 202, symbol: "BBB", name: "Beta", rank: 2)
        watchlistManager.addToWatchlist(coin)
        waitForOperationCompletion()
        XCTAssertTrue(watchlistManager.isInWatchlist(coinId: 202))
        
        // When
        watchlistManager.removeFromWatchlist(coinId: 202)
        waitForOperationCompletion()
        
        // Then
        XCTAssertFalse(watchlistManager.isInWatchlist(coinId: 202))
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 0)
    }
    
    // MARK: - Batch Operations
    
    func testBatchAddAndRemoveWatchlistItems() {
        // Given
        let coinsToAdd = makeCoins(5, startId: 1000)
        
        // When - Batch add
        watchlistManager.addMultipleToWatchlist(coinsToAdd)
        waitForOperationCompletion()
        
        // Then
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 5)
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 5)
        XCTAssertTrue(coinsToAdd.allSatisfy { watchlistManager.isInWatchlist(coinId: $0.id) })
        
        // When - Batch remove subset
        let idsToRemove = [1000, 1002, 1004]
        watchlistManager.removeMultipleFromWatchlist(coinIds: idsToRemove)
        waitForOperationCompletion()
        
        // Then - Remaining should be 2
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 2)
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 2)
        XCTAssertFalse(idsToRemove.contains { watchlistManager.isInWatchlist(coinId: $0) })
    }
    
    func testClearWatchlist() {
        // Given
        let coins = makeCoins(3, startId: 2000)
        watchlistManager.addMultipleToWatchlist(coins)
        waitForOperationCompletion()
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 3)
        
        // When
        watchlistManager.clearWatchlist()
        waitForOperationCompletion()
        
        // Then
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 0)
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 0)
    }
    
    // MARK: - Rollback Scenarios
    
    func testAddRollbackOnSaveFailure() {
        // Given - Failing context
        guard let failingStack = InMemoryCoreDataStack() else { XCTFail("Failed to create failing stack"); return }
        let failingManager = TestCoreDataManager(context: failingStack.makeFailingContext())
        let failingWatchlist = WatchlistManager(coreDataManager: failingManager,
                                                coinManager: coinManager,
                                                persistenceService: persistenceService)
        
        // Wait for initialization
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
        
        let coin = TestDataFactory.createMockCoin(id: 303, symbol: "CCC", name: "Gamma", rank: 3)
        
        // When
        failingWatchlist.addToWatchlist(coin)
        
        // Wait longer for rollback to occur
        let rollbackExpectation = XCTestExpectation(description: "Rollback completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            rollbackExpectation.fulfill()
        }
        wait(for: [rollbackExpectation], timeout: 2.0)
        
        // Then - Should rollback optimistic update
        XCTAssertFalse(failingWatchlist.isInWatchlist(coinId: 303))
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 0)
        _ = failingWatchlist // keep alive until test completes
    }
    
    func testBatchAddRollbackOnFailure() {
        // Given - Failing context
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
        
        let coins = makeCoins(4, startId: 4000)
        
        // When
        failingWatchlist.addMultipleToWatchlist(coins)
        
        // Wait longer for batch rollback to occur
        let rollbackExpectation = XCTestExpectation(description: "Batch rollback completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            rollbackExpectation.fulfill()
        }
        wait(for: [rollbackExpectation], timeout: 2.5)
        
        // Then - Should rollback all optimistic IDs
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 0)
        XCTAssertEqual(failingWatchlist.getWatchlistCount(), 0)
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


