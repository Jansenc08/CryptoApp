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
            // Use a main-queue context for simplicity in tests
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
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
            context.performAndWait {
                if context.hasChanges {
                    do { try context.save() } catch { XCTFail("Core Data save error: \(error)") }
                }
            }
        }
        
        func delete<T>(_ object: T) where T : NSManagedObject {
            context.performAndWait {
                context.delete(object)
                if context.hasChanges {
                    do { try context.save() } catch { XCTFail("Core Data delete save error: \(error)") }
                }
            }
        }
        
        func fetch<T>(_ objectType: T.Type) -> [T] where T : NSManagedObject {
            let entityName = String(describing: objectType)
            let request = NSFetchRequest<T>(entityName: entityName)
            request.includesPendingChanges = false
            var results: [T] = []
            context.performAndWait {
                do { results = try context.fetch(request) } catch { results = [] }
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
                do { results = try context.fetch(request) } catch { results = [] }
            }
            return results
        }
        
        func fetchWatchlistItems() -> [WatchlistItem] {
            let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
            request.includesPendingChanges = false
            var results: [WatchlistItem] = []
            context.performAndWait {
                do { results = try context.fetch(request) } catch { results = [] }
            }
            return results
        }
        
        func fetchWatchlistItems(where predicate: NSPredicate) -> [WatchlistItem] {
            let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
            request.predicate = predicate
            request.includesPendingChanges = false
            var results: [WatchlistItem] = []
            context.performAndWait {
                do { results = try context.fetch(request) } catch { results = [] }
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
        wait(seconds: 0.15) // Allow initializeLocalCache to complete
    }
    
    override func tearDown() {
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
    
    // MARK: - Core Data CRUD Tests
    
    func testAddAndFetchWatchlistItem() {
        // Given
        let coin = TestDataFactory.createMockCoin(id: 101, symbol: "AAA", name: "Alpha", rank: 1)
        
        // When
        watchlistManager.addToWatchlist(coin)
        wait(seconds: 0.25)
        
        // Then
        XCTAssertTrue(watchlistManager.isInWatchlist(coinId: 101))
        XCTAssertEqual(watchlistManager.getWatchlistCount(), coreDataManager.fetchWatchlistItems().count)
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 1)
    }
    
    func testRemoveWatchlistItem() {
        // Given
        let coin = TestDataFactory.createMockCoin(id: 202, symbol: "BBB", name: "Beta", rank: 2)
        watchlistManager.addToWatchlist(coin)
        wait(seconds: 0.25)
        XCTAssertTrue(watchlistManager.isInWatchlist(coinId: 202))
        
        // When
        watchlistManager.removeFromWatchlist(coinId: 202)
        wait(seconds: 0.25)
        
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
        wait(seconds: 0.35)
        
        // Then
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 5)
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 5)
        XCTAssertTrue(coinsToAdd.allSatisfy { watchlistManager.isInWatchlist(coinId: $0.id) })
        
        // When - Batch remove subset
        let idsToRemove = [1000, 1002, 1004]
        watchlistManager.removeMultipleFromWatchlist(coinIds: idsToRemove)
        wait(seconds: 0.35)
        
        // Then - Remaining should be 2
        XCTAssertEqual(coreDataManager.fetchWatchlistItems().count, 2)
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 2)
        XCTAssertFalse(idsToRemove.contains { watchlistManager.isInWatchlist(coinId: $0) })
    }
    
    func testClearWatchlist() {
        // Given
        let coins = makeCoins(3, startId: 2000)
        watchlistManager.addMultipleToWatchlist(coins)
        wait(seconds: 0.3)
        XCTAssertEqual(watchlistManager.getWatchlistCount(), 3)
        
        // When
        watchlistManager.clearWatchlist()
        wait(seconds: 0.3)
        
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
        wait(seconds: 0.25)
        let coin = TestDataFactory.createMockCoin(id: 303, symbol: "CCC", name: "Gamma", rank: 3)
        
        // When
        failingWatchlist.addToWatchlist(coin)
        wait(seconds: 0.5)
        
        // Then - Should rollback optimistic update
        XCTAssertFalse(failingWatchlist.isInWatchlist(coinId: 303))
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 0)
        _ = failingWatchlist // keep alive
    }
    
    func testBatchAddRollbackOnFailure() {
        // Given - Failing context
        guard let failingStack = InMemoryCoreDataStack() else { XCTFail("Failed to create failing stack"); return }
        let failingManager = TestCoreDataManager(context: failingStack.makeFailingContext())
        let failingWatchlist = WatchlistManager(coreDataManager: failingManager,
                                                coinManager: coinManager,
                                                persistenceService: persistenceService)
        wait(seconds: 0.25)
        let coins = makeCoins(4, startId: 4000)
        
        // When
        failingWatchlist.addMultipleToWatchlist(coins)
        wait(seconds: 0.6)
        
        // Then - Should rollback all optimistic IDs
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 0)
        XCTAssertEqual(failingWatchlist.getWatchlistCount(), 0)
        XCTAssertFalse(coins.contains { failingWatchlist.isInWatchlist(coinId: $0.id) })
        _ = failingWatchlist
    }
    
    func testBatchRemoveRollbackOnFailure() {
        // Given - Shared store with items added using working context
        guard let sharedStack = InMemoryCoreDataStack() else { XCTFail("Failed to create shared stack"); return }
        let writerManager = TestCoreDataManager(context: sharedStack.makeContext())
        // Pre-populate store
        let writerContext = writerManager.context
        let initialCoins = makeCoins(3, startId: 5000)
        initialCoins.forEach { _ = WatchlistItem(context: writerContext, coin: $0) }
        do { try writerContext.save() } catch { XCTFail("Prepopulation save failed: \(error)") }
        
        // Create failing manager sharing the same PSC
        let failingContext = InMemoryCoreDataStack.FailingContext(concurrencyType: .privateQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = sharedStack.persistentStoreCoordinator
        let failingManager = TestCoreDataManager(context: failingContext)
        let failingWatchlist = WatchlistManager(coreDataManager: failingManager,
                                                coinManager: coinManager,
                                                persistenceService: persistenceService)
        wait(seconds: 0.3)
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 3)
        
        // When - Attempt failing batch remove
        let idsToRemove = initialCoins.prefix(2).map { $0.id }
        failingWatchlist.removeMultipleFromWatchlist(coinIds: idsToRemove)
        wait(seconds: 0.6)
        
        // Then - Optimistic removal should be rolled back, DB unchanged
        XCTAssertEqual(failingManager.fetchWatchlistItems().count, 3)
        XCTAssertTrue(initialCoins.allSatisfy { failingWatchlist.isInWatchlist(coinId: $0.id) })
        _ = failingWatchlist
    }
}


