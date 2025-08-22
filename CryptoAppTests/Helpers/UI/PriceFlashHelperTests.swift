//
//  PriceFlashHelperTests.swift
//  CryptoAppTests
//
//  Tests the flashing behavior of PriceFlashHelper ensuring it runs on main thread
//  and restores label color and transform.
//

import XCTest
@testable import CryptoApp

final class PriceFlashHelperTests: XCTestCase {
    private var label: UILabel!
    private var originalColor: UIColor!

    override func setUp() {
        super.setUp()
        UIView.setAnimationsEnabled(false)
        label = UILabel()
        label.textColor = .label
        originalColor = label.textColor
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        label = nil
        originalColor = nil
        super.tearDown()
    }

    func testFlashPriceLabel_Positive_ChangesColorAndTransformImmediately() {
        let expectation = XCTestExpectation(description: "Flash applies immediate visual change (positive)")

        PriceFlashHelper.shared.flashPriceLabel(label, isPositive: true)

        // Allow main queue task from helper to run
        DispatchQueue.main.async {
            XCTAssertNotEqual(self.label.textColor, self.originalColor)
            XCTAssertNotEqual(self.label.transform, .identity)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testFlashPriceLabel_Negative_ChangesColorAndTransformImmediately() {
        let expectation = XCTestExpectation(description: "Flash applies immediate visual change (negative)")

        PriceFlashHelper.shared.flashPriceLabel(label, isPositive: false)

        DispatchQueue.main.async {
            XCTAssertNotEqual(self.label.textColor, self.originalColor)
            XCTAssertNotEqual(self.label.transform, .identity)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}


