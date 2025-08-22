import XCTest
@testable import CryptoApp

final class CollectionSafeTests: XCTestCase {
    func testSafeIndexing() {
        let array = [10, 20, 30]
        XCTAssertEqual(array[safe: 0], 10)
        XCTAssertEqual(array[safe: 2], 30)
        XCTAssertNil(array[safe: 3])
        XCTAssertNil(array[safe: -1])
    }

    func testUniquedByKeyPath() {
        struct Item { let id: Int; let name: String }
        let items = [Item(id: 1, name: "a"), Item(id: 1, name: "b"), Item(id: 2, name: "c")]
        let unique = items.uniqued(by: \Item.id)
        XCTAssertEqual(unique.count, 2)
        XCTAssertEqual(unique.map { $0.id }, [1,2])
    }

    func testUniquedByClosure() {
        let values = ["a", "A", "b", "B"]
        let unique = values.uniqued { $0.lowercased() }
        XCTAssertEqual(unique.count, 2)
        XCTAssertEqual(unique.map { $0.lowercased() }, ["a","b"])
    }
}


