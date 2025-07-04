//
//  CoinManager.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import Foundation
import Combine

final class CoinManager {
    
    private let coinService: CoinService
    
    init(coinService: CoinService = CoinService()) {
        self.coinService = coinService
    }

    func getTopCoins(limit: Int = 100, convert: String = "USD", start: Int = 1) -> AnyPublisher<[Coin], NetworkError> {
        return coinService.fetchTopCoins(limit: limit, convert: convert, start: start)
            .map { coins in
                // Do any data transformation here
                return coins
            }
            .eraseToAnyPublisher()
    }
    
    func getCoinLogos(forIDs ids: [Int]) -> AnyPublisher<[Int: String], Never> {
        return coinService.fetchCoinLogos(forIDs: ids)
       }
    
    func getQuotes(for ids: [Int], convert: String = "USD") -> AnyPublisher<[Int: Quote], NetworkError> {
        return coinService.fetchQuotes(for: ids, convert: convert)
    }

}
