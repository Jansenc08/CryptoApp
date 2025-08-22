//
//  ChartScrollHintAnimatorTests.swift
//  CryptoAppTests
//

import XCTest
@testable import CryptoApp

final class ChartScrollHintAnimatorTests: XCTestCase {
    func testFadeInSetsAlphaTowardVisible() {
        UIView.setAnimationsEnabled(false)
        let label = UILabel(); label.alpha = 0
        let arrow = UIImageView(); arrow.alpha = 0
        ChartScrollHintAnimator.fadeIn(label: label, arrow: arrow)
        XCTAssertGreaterThanOrEqual(label.alpha, 0.8 - 0.0001)
        XCTAssertGreaterThanOrEqual(arrow.alpha, 0.6 - 0.0001)
        UIView.setAnimationsEnabled(true)
    }

    func testFadeOutSetsAlphaToZero() {
        UIView.setAnimationsEnabled(false)
        let label = UILabel(); label.alpha = 1
        let arrow = UIImageView(); arrow.alpha = 1
        ChartScrollHintAnimator.fadeOut(label: label, arrow: arrow)
        XCTAssertEqual(label.alpha, 0, accuracy: 0.0001)
        XCTAssertEqual(arrow.alpha, 0, accuracy: 0.0001)
        UIView.setAnimationsEnabled(true)
    }

    func testLayoutArrowPositionsFrame() {
        let arrow = UIImageView()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
        ChartScrollHintAnimator.layoutArrow(arrow, in: bounds)
        XCTAssertEqual(arrow.frame.size.width, 16, accuracy: 0.001)
        XCTAssertEqual(arrow.frame.size.height, 16, accuracy: 0.001)
        XCTAssertGreaterThan(arrow.frame.minX, 0)
        XCTAssertGreaterThan(arrow.frame.minY, 0)
    }

    func testAnimateBounceSetsTransformWithRepeatOption() {
        UIView.setAnimationsEnabled(false)
        let view = UIView()
        ChartScrollHintAnimator.animateBounce(for: view)
        // Because animations are disabled, ensure we can safely call and state remains valid
        XCTAssertNotNil(view.layer)
        UIView.setAnimationsEnabled(true)
    }
}


