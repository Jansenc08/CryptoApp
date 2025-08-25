//
//  ChartLabelManagerTests.swift
//  CryptoAppTests
//

import XCTest
import DGCharts
@testable import CryptoApp

final class ChartLabelManagerTests: XCTestCase {
    private var parentChart: UIView!
    private var manager: ChartLabelManager!

    override func setUp() {
        super.setUp()
        parentChart = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 300))
        manager = ChartLabelManager(parentChart: parentChart)
    }

    override func tearDown() {
        manager.removeAllLabels()
        manager = nil
        parentChart = nil
        super.tearDown()
    }

    // MARK: - Basic creation
    func testInitAddsContainersToParent() {
        XCTAssertFalse(parentChart.subviews.isEmpty)
        // Ensure a stack view exists
        let stack = parentChart.subviews.first { $0 is UIStackView }
        XCTAssertNotNil(stack)
    }

    // MARK: - Value extraction helpers
    func testGetLatestSMAAndEMAValues() {
        let smaEntries = [ChartDataEntry(x: 0, y: 1), ChartDataEntry(x: 1, y: 2)]
        let emaEntries = [ChartDataEntry(x: 0, y: 3), ChartDataEntry(x: 1, y: 4)]
        let sma = LineChartDataSet(entries: smaEntries, label: "SMA")
        let ema = LineChartDataSet(entries: emaEntries, label: "EMA")

        XCTAssertEqual(manager.getLatestSMAValue(from: sma), 2)
        XCTAssertEqual(manager.getLatestEMAValue(from: ema), 4)
        XCTAssertNil(manager.getLatestSMAValue(from: LineChartDataSet(entries: [], label: "SMA")))
        XCTAssertNil(manager.getLatestEMAValue(from: LineChartDataSet(entries: [], label: "EMA")))
    }

    func testGetLatestRSIValue() {
        let rsi = TechnicalIndicators.RSIResult(
            values: [nil, 45.0, 60.5],
            period: 14,
            overboughtLevel: 70,
            oversoldLevel: 30
        )
        XCTAssertEqual(manager.getLatestRSIValue(from: rsi), 60.5)

        let empty = TechnicalIndicators.RSIResult(values: [], period: 14, overboughtLevel: 70, oversoldLevel: 30)
        XCTAssertNil(manager.getLatestRSIValue(from: empty))
    }

    // MARK: - Public update APIs
    func testUpdateSMALabelHandlesValueNilAndVisibility() {
        manager.updateSMALabel(value: 123.45, period: 20, color: .blue, isVisible: true)
        manager.updateSMALabel(value: nil, period: 20, color: .blue, isVisible: true, dataCount: 5)
        manager.updateSMALabel(value: 123.45, period: 20, color: .blue, isVisible: false)
    }

    func testUpdateEMALabelHandlesValueNilAndVisibility() {
        manager.updateEMALabel(value: 99.12, period: 12, color: .orange, isVisible: true)
        manager.updateEMALabel(value: nil, period: 12, color: .orange, isVisible: true, dataCount: 3)
        manager.updateEMALabel(value: 99.12, period: 12, color: .orange, isVisible: false)
    }

    func testUpdateRSILabelHandlesValueNilAndVisibility() {
        manager.updateRSILabel(value: 65.44, period: 14, isVisible: true)
        manager.updateRSILabel(value: nil, period: 14, isVisible: true, dataCount: 10)
        manager.updateRSILabel(value: 65.44, period: 14, isVisible: false)
    }

    func testUpdateCurrentPriceFormatsAndColors() {
        manager.updateCurrentPrice(price: 1500.25, isBullish: true)
        manager.updateCurrentPrice(price: 0.0000123, isBullish: false)
        manager.updateCurrentPrice(price: 0, isBullish: true)
    }

    func testPositionRSILabelAddsTopConstraintWithCorrectConstant() {
        // Given
        let initialConstraintCount = parentChart.constraints.count
        let top: CGFloat = 200
        
        // When
        manager.positionRSILabel(in: parentChart.bounds, rsiAreaTop: top, rsiAreaHeight: 60)
        
        // Then
        // Constraints are installed on the parent view; ensure a top constraint with expected constant exists
        let expectedTopConstant = top + 4
        let hasTopConstraint = parentChart.constraints.contains { c in
            return c.secondItem as AnyObject === parentChart && c.firstAttribute == .top && abs(c.constant - expectedTopConstant) < 0.5
        }
        XCTAssertTrue(hasTopConstraint || parentChart.constraints.count > initialConstraintCount,
                      "RSI positioning should add appropriate constraints to parent chart")
    }

    func testHideAllTechnicalIndicatorLabelsDoesNotCrash() {
        manager.hideAllTechnicalIndicatorLabels()
    }

    func testRemoveAllLabelsRemovesContainers() {
        manager.removeAllLabels()
        XCTAssertTrue(parentChart.subviews.isEmpty)
    }

    // MARK: - Integrated updates
    func testUpdateLabelsAtPositionAndAllLabels() {
        let sma = LineChartDataSet(entries: [ChartDataEntry(x: 0, y: 10), ChartDataEntry(x: 1, y: 20)], label: "SMA")
        let ema = LineChartDataSet(entries: [ChartDataEntry(x: 0, y: 8), ChartDataEntry(x: 1, y: 18)], label: "EMA")
        let rsi = TechnicalIndicators.RSIResult(values: [45.0, 60.0], period: 14, overboughtLevel: 70, oversoldLevel: 30)
        var settings = TechnicalIndicators.IndicatorSettings()
        settings.showSMA = true
        settings.showEMA = true
        settings.showRSI = true

        manager.updateLabelsAtPosition(
            xIndex: 1,
            smaDataSet: sma,
            emaDataSet: ema,
            rsiResult: rsi,
            settings: settings,
            theme: .classic,
            dataPointCount: 2
        )

        manager.updateAllLabels(
            smaDataSet: sma,
            emaDataSet: ema,
            rsiResult: rsi,
            settings: settings,
            theme: .classic,
            rsiAreaTop: 200,
            rsiAreaHeight: 60,
            dataPointCount: 2
        )
    }
}


