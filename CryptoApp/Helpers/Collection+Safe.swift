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
