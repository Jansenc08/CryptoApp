//
//  PersistenceServiceTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests validating PersistenceService contract semantics using MockPersistenceService:
//  - Save/load coins and logos
//  - Cache expiry behavior (fresh vs simulated expired)
//  - Offline data tuple (coins/logos)
//

import XCTest
@testable import CryptoApp

final class PersistenceServiceTests: XCTestCase {
    
    func testMockPersistenceSaveLoadCoinsAndLogos() {
        // Using mock persistence to validate contract semantics
        let persistence = MockPersistenceService()
        let coins = TestDataFactory.createMockCoins(count: 5)
        let logos = TestDataFactory.createMockLogos(for: coins.map { $0.id })
        
        persistence.saveCoinList(coins)
        persistence.saveCoinLogos(logos)
        
        XCTAssertEqual(persistence.loadCoinList()?.count, 5)
        XCTAssertEqual(persistence.loadCoinLogos()?.count, logos.count)
        
        // Cache timing
        XCTAssertEqual(persistence.isCacheExpired(maxAge: 3600), false)
        // Force expired
        persistence.shouldSimulateExpiredCache = true
        XCTAssertEqual(persistence.isCacheExpired(maxAge: 3600), true)
        
        // Offline tuple
        let offline = persistence.getOfflineData()
        XCTAssertNotNil(offline)
        XCTAssertEqual(offline?.coins.count, 5)
    }
}
