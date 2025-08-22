import XCTest
import DGCharts
@testable import CryptoApp

final class ChartConfigurationHelperTests: XCTestCase {
    func testCalculateVisiblePoints() {
        XCTAssertEqual(ChartConfigurationHelper.calculateVisiblePoints(for: "24h", dataCount: 10), 10)
        XCTAssertEqual(ChartConfigurationHelper.calculateVisiblePoints(for: "7d", dataCount: 1000), 50)
        XCTAssertEqual(ChartConfigurationHelper.calculateVisiblePoints(for: "30d", dataCount: 59), 59)
        XCTAssertEqual(ChartConfigurationHelper.calculateVisiblePoints(for: "All", dataCount: 500), 100)
    }

    func testConfigureLineChartBasicSettings() {
        let chart = LineChartView(frame: .init(x: 0, y: 0, width: 320, height: 200))
        ChartConfigurationHelper.configureBasicSettings(for: chart)
        XCTAssertTrue(chart.legend.enabled == false)
        XCTAssertTrue(chart.scaleXEnabled)
        XCTAssertTrue(chart.scaleYEnabled)
        XCTAssertTrue(chart.dragEnabled)
        XCTAssertTrue(chart.pinchZoomEnabled)
    }

    func testAxesConfigurationSetsFormatters() {
        let chart = LineChartView(frame: .init(x: 0, y: 0, width: 320, height: 200))
        ChartConfigurationHelper.configureAxes(for: chart)
        XCTAssertTrue(chart.leftAxis.enabled == false)
        XCTAssertNotNil(chart.rightAxis.valueFormatter)
        XCTAssertNotNil(chart.xAxis.valueFormatter)
    }
}


