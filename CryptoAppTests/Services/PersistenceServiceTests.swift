//
//  PersistenceServiceTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for PersistenceService covering coin list and logo storage,
//  last cache time + expiry logic, offline data round-trip, and clear.
//  Pattern: uses a fresh PersistenceService instance and clears keys in setUp/tearDown.
//

import XCTest
@testable import CryptoApp

final class PersistenceServiceTests: XCTestCase {
    
    private var persistence: PersistenceService!
    
    override func setUp() {
        super.setUp()
        // Fresh instance; clear any leftover data to isolate tests
        persistence = PersistenceService()
        persistence.clearCache()
    }
    
    override func tearDown() {
        persistence.clearCache()
        persistence = nil
        super.tearDown()
    }
    
    // MARK: - Coin List
    
    func testSaveThenLoadCoinListPersists() {
        // Given
        // Create a small set of coins and save them
        let coins = TestDataFactory.createMockCoins(count: 3)
        persistence.saveCoinList(coins)
        
        // When
        let loaded = persistence.loadCoinList()
        
        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 3)
        XCTAssertEqual(loaded?.first?.id, 1)
    }
    
    // MARK: - Logos
    
    func testSaveThenLoadCoinLogosPersists() {
        // Given
        let logos: [Int: String] = [1: "logo1.png", 2: "logo2.png"]
        persistence.saveCoinLogos(logos)
        
        // When
        let loaded = persistence.loadCoinLogos()
        
        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?[1], "logo1.png")
        XCTAssertEqual(loaded?[2], "logo2.png")
    }
    
    // MARK: - Cache Time + Expiry
    
    func testLastCacheTimeAndExpiryLogic() {
        // Given
        // Saving coin list sets the last cache time
        persistence.saveCoinList(TestDataFactory.createMockCoins(count: 1))
        
        // When
        let last = persistence.getLastCacheTime()
        let notExpired = persistence.isCacheExpired(maxAge: 10_000) // generous max age
        let expiredImmediately = persistence.isCacheExpired(maxAge: 0)
        
        // Then
        XCTAssertNotNil(last)
        XCTAssertFalse(notExpired)
        XCTAssertTrue(expiredImmediately)
    }
    
    // MARK: - Offline Data
    
    func testSaveAndLoadOfflineDataPersists() {
        // Given
        let coins = TestDataFactory.createMockCoins(count: 2)
        let logos = TestDataFactory.createMockLogos(for: coins.map { $0.id })
        persistence.saveOfflineData(coins: coins, logos: logos)
        
        // When
        let offline = persistence.getOfflineData()
        
        // Then
        XCTAssertNotNil(offline)
        XCTAssertEqual(offline?.coins.count, 2)
        XCTAssertEqual(offline?.logos.count, logos.count)
    }
    
    // MARK: - Clear Cache
    
    func testClearCacheRemovesAllData() {
        // Given
        persistence.saveCoinList(TestDataFactory.createMockCoins(count: 1))
        persistence.saveCoinLogos([1: "logo.png"])
        XCTAssertNotNil(persistence.loadCoinList())
        XCTAssertNotNil(persistence.loadCoinLogos())
        
        // When
        persistence.clearCache()
        
        // Then
        XCTAssertNil(persistence.loadCoinList())
        XCTAssertNil(persistence.loadCoinLogos())
        XCTAssertNil(persistence.getLastCacheTime())
    }
}


