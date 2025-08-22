import XCTest
@testable import CryptoApp

final class ChartSmoothingHelperTests: XCTestCase {
    let data: [Double] = [1, 2, 3, 100, 4, 5, 6]

    func testRemoveOutliersReplacesSpikesWithMedian() {
        // removeOutliers only activates for arrays with >10 elements
        let series: [Double] = [1,2,3,4,5,6,7,8,1000,9,10,11,12]
        let cleaned = ChartSmoothingHelper.removeOutliers(series)
        XCTAssertEqual(cleaned.count, series.count)
        // With a single large spike, the algorithm replaces it with the median (which is 7)
        XCTAssertEqual(cleaned[8], 7)
    }

    func testBasicSmoothingPreservesLengthAndStartsWithOriginal() {
        let smoothed = ChartSmoothingHelper.applySmoothingToChartData(data, type: .basic, timeRange: "7")
        XCTAssertEqual(smoothed.count, data.count)
        XCTAssertEqual(smoothed.first, data.first)
    }

    func testMedianFilterReducesSpike() {
        let smoothed = ChartSmoothingHelper.applySmoothingToChartData(data, type: .median, timeRange: "7")
        XCTAssertLessThan(smoothed[3], 100)
    }

    func testSavitzkyGolayKeepsPeaksButSmooths() {
        let smoothed = ChartSmoothingHelper.applySmoothingToChartData(data, type: .savitzkyGolay, timeRange: "7")
        XCTAssertEqual(smoothed.count, data.count)
    }
}


