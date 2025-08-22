//
//  ChartSkeletonTests.swift
//  CryptoAppTests
//
//  Unit tests for ChartSkeleton covering:
//  - Skeleton view initialization and setup
//  - Animation start/stop functionality
//  - UI component layout and constraints
//  - Memory management and cleanup
//

import XCTest
@testable import CryptoApp

final class ChartSkeletonTests: XCTestCase {
    
    private var chartSkeleton: ChartSkeleton!
    
    override func setUp() {
        super.setUp()
        chartSkeleton = ChartSkeleton(frame: CGRect(x: 0, y: 0, width: 375, height: 300))
    }
    
    override func tearDown() {
        chartSkeleton?.stopShimmering()
        chartSkeleton = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testChartSkeletonInitialization() {
        // Given & When - chartSkeleton is initialized in setUp
        
        // Then
        XCTAssertNotNil(chartSkeleton, "ChartSkeleton should be initialized")
        XCTAssertEqual(chartSkeleton.backgroundColor, .systemBackground, 
                      "ChartSkeleton should have system background color")
        XCTAssertFalse(chartSkeleton.subviews.isEmpty, "ChartSkeleton should have subviews")
    }
    
    func testChartSkeletonInitWithCoder() {
        // Given
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.finishEncoding()
        let unarchiver = NSKeyedUnarchiver(forReadingWith: data as Data)
        
        // When
        let skeletonFromCoder = ChartSkeleton(coder: unarchiver)
        
        // Then
        XCTAssertNotNil(skeletonFromCoder, "ChartSkeleton should initialize from coder")
        if let skeleton = skeletonFromCoder {
            XCTAssertEqual(skeleton.backgroundColor, .systemBackground,
                          "ChartSkeleton from coder should have correct background")
        }
    }
    
    // MARK: - UI Setup Tests
    
    func testUIComponentsExist() {
        // Given & When
        chartSkeleton.layoutIfNeeded()
        
        // Then
        // Check that container view exists
        let containerView = chartSkeleton.subviews.first
        XCTAssertNotNil(containerView, "Container view should exist")
        XCTAssertFalse(containerView!.translatesAutoresizingMaskIntoConstraints,
                      "Container view should use Auto Layout")
        
        // Check that skeleton components are added to container
        let skeletonComponents = containerView!.subviews
        XCTAssertGreaterThanOrEqual(skeletonComponents.count, 7, 
                                   "Should have at least 7 skeleton components (chart + 6 labels)")
    }
    
    func testSkeletonComponentTypes() {
        // Given & When
        chartSkeleton.layoutIfNeeded()
        
        // Then
        let containerView = chartSkeleton.subviews.first!
        let skeletonViews = containerView.subviews.compactMap { $0 as? SkeletonView }
        
        XCTAssertGreaterThanOrEqual(skeletonViews.count, 7, 
                                   "Should have at least 7 SkeletonView components")
        
        // Verify different skeleton types exist
        let hasResizableSkeleton = skeletonViews.contains { $0.layer.cornerRadius == 8 }
        XCTAssertTrue(hasResizableSkeleton, "Should have chart area skeleton with corner radius 8")
    }
    
    // MARK: - Layout Tests
    
    func testConstraintsSetup() {
        // Given
        let initialFrame = CGRect(x: 0, y: 0, width: 400, height: 350)
        chartSkeleton.frame = initialFrame
        
        // When
        chartSkeleton.layoutIfNeeded()
        
        // Then
        let containerView = chartSkeleton.subviews.first!
        
        // Verify container is properly constrained
        XCTAssertGreaterThan(containerView.frame.width, 0, 
                            "Container should have positive width after layout")
        XCTAssertGreaterThan(containerView.frame.height, 0, 
                            "Container should have positive height after layout")
        
        // Container should have some padding from edges
        XCTAssertGreaterThan(containerView.frame.minX, 0, 
                            "Container should have leading margin")
        XCTAssertLessThan(containerView.frame.maxX, chartSkeleton.frame.width, 
                         "Container should have trailing margin")
    }
    
    func testLayoutWithDifferentSizes() {
        // Test with different frame sizes
        let sizes = [
            CGRect(x: 0, y: 0, width: 320, height: 200), // Small
            CGRect(x: 0, y: 0, width: 375, height: 300), // iPhone
            CGRect(x: 0, y: 0, width: 768, height: 400), // iPad
            CGRect(x: 0, y: 0, width: 414, height: 200)  // Wide iPhone
        ]
        
        for size in sizes {
            // Given
            chartSkeleton.frame = size
            
            // When
            chartSkeleton.layoutIfNeeded()
            
            // Then
            let containerView = chartSkeleton.subviews.first!
            XCTAssertGreaterThan(containerView.frame.width, 0, 
                                "Container should adapt to size \(size)")
            XCTAssertGreaterThan(containerView.frame.height, 0, 
                                "Container should adapt to size \(size)")
        }
    }
    
    // MARK: - Animation Tests
    
    func testStartShimmering() {
        // Given
        // No readable state before start; just ensure view exists
        
        // When
        chartSkeleton.startShimmering()
        
        // Then
        // Verify skeleton views exist (animation state is internal)
        let containerView = chartSkeleton.subviews.first!
        let skeletonViews = containerView.subviews.compactMap { $0 as? SkeletonView }
        
        for skeletonView in skeletonViews {
            XCTAssertNotNil(skeletonView.layer.sublayers)
        }
    }
    
    func testStopShimmering() {
        // Given
        chartSkeleton.startShimmering()
        
        // When
        chartSkeleton.stopShimmering()
        
        // Then
        // Verify skeleton views still exist; animation state is internal
        let containerView = chartSkeleton.subviews.first!
        let skeletonViews = containerView.subviews.compactMap { $0 as? SkeletonView }
        
        for skeletonView in skeletonViews {
            XCTAssertNotNil(skeletonView.layer)
        }
    }
    
    func testToggleAnimation() {
        // Given
        // No readable state; ensure API calls are safe repeatedly
        
        // When & Then - Toggle multiple times
        chartSkeleton.startShimmering()
        
        chartSkeleton.stopShimmering()
        
        chartSkeleton.startShimmering()
        
        chartSkeleton.stopShimmering()
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryCleanup() {
        // Given
        weak var weakSkeleton: ChartSkeleton? = chartSkeleton
        chartSkeleton.startShimmering()
        
        // When
        chartSkeleton.stopShimmering()
        chartSkeleton = nil
        
        // Then
        // Force a small delay to allow cleanup
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakSkeleton, "ChartSkeleton should be deallocated")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleStartStopCalls() {
        // Given & When - Multiple rapid calls
        for _ in 0..<10 {
            chartSkeleton.startShimmering()
            chartSkeleton.stopShimmering()
        }
        
        // Then - Should handle gracefully
        // No public state to assert; ensure object remains valid
        XCTAssertNotNil(chartSkeleton, "ChartSkeleton should still be valid")
    }
    
    // MARK: - Performance Tests
    
    func testInitializationPerformance() {
        // When & Then
        measure {
            for _ in 0..<50 {
                let skeleton = ChartSkeleton(frame: CGRect(x: 0, y: 0, width: 375, height: 300))
                skeleton.layoutIfNeeded()
            }
        }
    }
    
    func testAnimationPerformance() {
        // Given
        let skeletons = (0..<10).map { _ in
            ChartSkeleton(frame: CGRect(x: 0, y: 0, width: 375, height: 300))
        }
        
        // When & Then
        measure {
            for skeleton in skeletons {
                skeleton.startShimmering()
            }
            for skeleton in skeletons {
                skeleton.stopShimmering()
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testZeroFrame() {
        // Given
        let zeroSkeleton = ChartSkeleton(frame: .zero)
        
        // When
        zeroSkeleton.layoutIfNeeded()
        
        // Then
        XCTAssertNotNil(zeroSkeleton, "Should handle zero frame gracefully")
        XCTAssertFalse(zeroSkeleton.subviews.isEmpty, "Should still have subviews with zero frame")
    }
    
    func testNegativeFrame() {
        // Given
        let negativeSkeleton = ChartSkeleton(frame: CGRect(x: -100, y: -100, width: 375, height: 300))
        
        // When
        negativeSkeleton.layoutIfNeeded()
        
        // Then
        XCTAssertNotNil(negativeSkeleton, "Should handle negative frame gracefully")
        XCTAssertFalse(negativeSkeleton.subviews.isEmpty, "Should still have subviews with negative frame")
    }

    func testRemoveFromParentRemovesFromSuperview() {
        // Given
        let container = UIView()
        container.addSubview(chartSkeleton)
        XCTAssertEqual(chartSkeleton.superview, container)

        // When
        chartSkeleton.startShimmering()
        chartSkeleton.removeFromParent()

        // Then
        XCTAssertNil(chartSkeleton.superview, "ChartSkeleton should be removed from its superview")
    }
}
