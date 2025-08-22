import XCTest
@testable import CryptoApp

final class DoubleAbbreviationTests: XCTestCase {
    func testAbbreviations() {
        XCTAssertEqual(1_234.0.abbreviatedString(), "1.2K")
        let twoM = 2_000_000.0.abbreviatedString()
        XCTAssertTrue(twoM == "2.0M" || twoM == "2M")
        XCTAssertEqual(3_500_000_000.0.abbreviatedString(), "3.5B")
        let fourT = 4_000_000_000_000.0.abbreviatedString()
        XCTAssertTrue(fourT == "4.0T" || fourT == "4T")
    }

    func testSmallAndNegativeValues() {
        let small = 999.0.abbreviatedString()
        XCTAssertTrue(small == "999.0" || small == "999")
        let zero = 0.0.abbreviatedString()
        XCTAssertTrue(zero == "0.0" || zero == "0")
        XCTAssertTrue((-1234.0).abbreviatedString().contains("-"))
    }
}


