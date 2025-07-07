//
//  CoinHistoryPoint.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

// This struct will hold the response from CoinGecko's market_chart endpoint
struct CoinGeckoChartResponse: Decodable {
    let prices: [[Double]] // Each inner array is [timestamp, price]
    let market_caps: [[Double]] // Example: if you wanted market caps
    let total_volumes: [[Double]] // Example: if you wanted total volumes
}
