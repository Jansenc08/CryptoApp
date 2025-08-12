//
//  Collection+Safe.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 4/7/25.
//

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Sequence {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
    
    func uniqued<T: Hashable>(by closure: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert(closure($0)).inserted }
    }
}
