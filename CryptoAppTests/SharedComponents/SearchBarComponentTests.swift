//
//  SearchBarComponentTests.swift
//  CryptoAppTests
//

import XCTest
@testable import CryptoApp

private final class SearchBarDelegateSpy: NSObject, SearchBarComponentDelegate {
    var didChangeText: [String] = []
    var didBeginEditing = false
    var didEndEditing = false
    var didTapSearch = false
    var didTapCancel = false

    func searchBarComponent(_ searchBar: SearchBarComponent!, textDidChange searchText: String!) {
        didChangeText.append(searchText)
    }
    func searchBarComponentDidBeginEditing(_ searchBar: SearchBarComponent!) {
        didBeginEditing = true
    }
    func searchBarComponentDidEndEditing(_ searchBar: SearchBarComponent!) {
        didEndEditing = true
    }
    func searchBarComponentSearchButtonClicked(_ searchBar: SearchBarComponent!) {
        didTapSearch = true
    }
    func searchBarComponentCancelButtonClicked(_ searchBar: SearchBarComponent!) {
        didTapCancel = true
    }
}

final class SearchBarComponentTests: XCTestCase {
    func testInitializationWithPlaceholder() {
        let component = SearchBarComponent(placeholder: "Find coin")
        // The component stores placeholder on its UISearchBar
        XCTAssertEqual(component.searchBar.placeholder, "Find coin")
        XCTAssertEqual(component.searchBar.searchBarStyle, .minimal)
    }

    func testPublicPropertiesAndMethods() {
        let component = SearchBarComponent(placeholder: nil, style: .minimal)
        component.tintColor = .systemRed
        XCTAssertEqual(component.searchBar.tintColor, .systemRed)

        component.text = "btc"
        XCTAssertEqual(component.text, "btc")
        XCTAssertEqual(component.searchBar.text, "btc")

        component.setShowsCancelButton(true, animated: false)
        XCTAssertTrue(component.showsCancelButton)

        component.clearText()
        XCTAssertEqual(component.text, "")
    }

    func testDelegateCallbacks() {
        let component = SearchBarComponent(placeholder: "Search")
        let spy = SearchBarDelegateSpy()
        component.delegate = spy

        // Simulate delegate callbacks via UISearchBar's delegate
        component.searchBar.text = "eth"
        component.searchBar.delegate?.searchBar?(component.searchBar, textDidChange: "eth")
        XCTAssertEqual(spy.didChangeText, ["eth"])

        component.searchBar.delegate?.searchBarTextDidBeginEditing?(component.searchBar)
        XCTAssertTrue(spy.didBeginEditing)

        component.searchBar.delegate?.searchBarTextDidEndEditing?(component.searchBar)
        XCTAssertTrue(spy.didEndEditing)

        component.searchBar.delegate?.searchBarSearchButtonClicked?(component.searchBar)
        XCTAssertTrue(spy.didTapSearch)

        component.searchBar.delegate?.searchBarCancelButtonClicked?(component.searchBar)
        XCTAssertTrue(spy.didTapCancel)
        XCTAssertEqual(component.text, "") // clearText is called on cancel
    }

    func testConfigurationModes() {
        let component = SearchBarComponent(placeholder: nil)
        component.configureForFullScreenSearch()
        XCTAssertEqual(component.searchBar.searchBarStyle, .minimal)
        XCTAssertEqual(component.searchBar.placeholder, "Search cryptocurrencies...")

        component.configureForInlineSearch()
        XCTAssertEqual(component.searchBar.searchBarStyle, .minimal)
        XCTAssertEqual(component.searchBar.placeholder, "Search coins to add...")
    }
}


