//
//  TechnicalIndicatorsTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for TechnicalIndicators covering SMA/EMA/RSI calculations,
//  volume analysis, settings persistence, and color mapping.
//  Patterns:
//  - Deterministic numeric inputs with hand-computed expectations
//  - Edge-case coverage for insufficient data and division-by-zero protection
//

import XCTest
@testable import CryptoApp

final class TechnicalIndicatorsTests: XCTestCase {
    
    // MARK: - SMA
    
    func testCalculateSMAReturnsExpectedValues() {
        // Given
        // Prices 1..5 and period 3 -> SMA should be [nil, nil, 2, 3, 4]
        let prices: [Double] = [1, 2, 3, 4, 5]
        let period = 3
        
        // When
        // Calculate SMA over the provided price sequence
        let result = TechnicalIndicators.calculateSMA(prices: prices, period: period)
        
        // Then
        // Verify windowing and averaged values align with hand-calculated expectations
        XCTAssertEqual(result.period, 3)
        XCTAssertEqual(result.values.count, 5)
        XCTAssertNil(result.values[0])
        XCTAssertNil(result.values[1])
        XCTAssertEqual(result.values[2], 2)
        XCTAssertEqual(result.values[3], 3)
        XCTAssertEqual(result.values[4], 4)
    }
    
    func testCalculateSMAInsufficientDataReturnsNils() {
        // Given
        // Period exceeds available samples → result should be all nils
        let prices: [Double] = [1, 2]
        
        // When
        let result = TechnicalIndicators.calculateSMA(prices: prices, period: 3)
        
        // Then
        // Entire result should be nil because there is insufficient data to compute any window
        XCTAssertEqual(result.values, [nil, nil])
    }
    
    // MARK: - EMA
    
    func testCalculateEMAUsesSMAToSeedAndSmoothsCorrectly() {
        // Given
        // For prices 1..5 and period 3, multiplier = 0.5 → EMA should be [nil, nil, 2, 3, 4]
        let prices: [Double] = [1, 2, 3, 4, 5]
        let period = 3
        
        // When
        // Calculate EMA; first EMA seeds from SMA then applies smoothing
        let result = TechnicalIndicators.calculateEMA(prices: prices, period: period)
        
        // Then
        // Verify nil preface, SMA-seeded first value, and subsequent smoothing
        XCTAssertEqual(result.period, 3)
        XCTAssertEqual(result.values.count, 5)
        XCTAssertNil(result.values[0])
        XCTAssertNil(result.values[1])
        XCTAssertEqual(result.values[2], 2.0)
        XCTAssertEqual(result.values[3], 3.0)
        XCTAssertEqual(result.values[4], 4.0)
    }
    
    func testCalculateEMAInsufficientDataReturnsNils() {
        // Given
        // Not enough samples to compute initial SMA seed → all nils
        let prices: [Double] = [1, 2]
        
        // When
        let result = TechnicalIndicators.calculateEMA(prices: prices, period: 3)
        
        // Then
        XCTAssertEqual(result.values, [nil, nil])
    }
    
    // MARK: - RSI
    
    func testCalculateRSIRequiresAtLeastPeriodPlusOnePrices() {
        // Given
        // Less than (period + 1) prices should produce nils only
        let prices: [Double] = Array(repeating: 1.0, count: 10)
        let period = 14
        
        // When
        let rsi = TechnicalIndicators.calculateRSI(prices: prices, period: period)
        
        // Then
        XCTAssertEqual(rsi.values.count, prices.count)
        XCTAssertTrue(rsi.values.allSatisfy { $0 == nil })
    }
    
    func testCalculateRSIProducesValuesInValidRange() {
        // Given
        // Strictly increasing prices drive RS high; final RSI must remain within [0, 100]
        let prices: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        
        // When
        // Compute RSI with default period
        let rsi = TechnicalIndicators.calculateRSI(prices: prices, period: 14)
        
        // Then
        // First (period) entries are nil; trailing values must be within range
        XCTAssertEqual(rsi.values.count, prices.count)
        // First 14 should be nil per implementation; from index 14 onward values exist
        XCTAssertTrue(rsi.values[0..<14].allSatisfy { $0 == nil })
        if let last = rsi.values.last ?? nil {
            XCTAssertGreaterThanOrEqual(last, 0)
            XCTAssertLessThanOrEqual(last, 100)
        } else {
            XCTFail("Expected last RSI value to be non-nil")
        }
    }
    
    // MARK: - Volume Analysis
    
    func testAnalyzeVolumeFlagsHighVolumeWhenAboveThreshold() {
        // Given
        // With SMA period 2, the last average is (10 + 31) / 2 = 20; 31/20 = 1.55 (> 1.5)
        let volumes: [Double] = [10, 10, 10, 31]
        
        // When
        // Analyze volumes with a small period to make high-volume detection sensitive
        let analysis = TechnicalIndicators.analyzeVolume(volumes: volumes, period: 2)
        
        // Then
        // Verify data alignment and that the last period is flagged as high volume
        XCTAssertEqual(analysis.volumes.count, volumes.count)
        XCTAssertEqual(analysis.volumeRatio.count, volumes.count)
        XCTAssertEqual(analysis.isHighVolume.count, volumes.count)
        XCTAssertTrue(analysis.isHighVolume.last ?? false)
    }
    
    // MARK: - Settings Persistence
    
    func testIndicatorSettingsSaveAndLoadRoundTrip() {
        // Given
        // Customize settings to ensure values persist across save/load
        var settings = TechnicalIndicators.IndicatorSettings()
        settings.showSMA = true
        settings.smaPeriod = 50
        settings.showEMA = true
        settings.emaPeriod = 21
        settings.showRSI = true
        settings.rsiPeriod = 9
        settings.rsiOverbought = 80
        settings.rsiOversold = 20
        settings.showVolume = false
        
        // When
        // Save then load settings from UserDefaults
        TechnicalIndicators.saveIndicatorSettings(settings)
        let loaded = TechnicalIndicators.loadIndicatorSettings()
        
        // Then
        // Verify all fields round-trip correctly
        XCTAssertEqual(loaded.showSMA, true)
        XCTAssertEqual(loaded.smaPeriod, 50)
        XCTAssertEqual(loaded.showEMA, true)
        XCTAssertEqual(loaded.emaPeriod, 21)
        XCTAssertEqual(loaded.showRSI, true)
        XCTAssertEqual(loaded.rsiPeriod, 9)
        XCTAssertEqual(loaded.rsiOverbought, 80)
        XCTAssertEqual(loaded.rsiOversold, 20)
        XCTAssertEqual(loaded.showVolume, false)
    }
    
    // MARK: - Color Mapping
    
    func testGetIndicatorColorFallbackForUnknownIndicator() {
        // Given
        // Unknown indicator keys should return a safe fallback color
        let theme = ChartColorTheme.classic
        
        // When
        // Request color for an unrecognized indicator name
        let color = TechnicalIndicators.getIndicatorColor(for: "unknown", theme: theme)
        
        // Then
        XCTAssertEqual(color, UIColor.label)
    }
}


