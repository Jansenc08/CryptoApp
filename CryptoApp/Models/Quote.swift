//
//  Quote.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import Foundation

struct Quote: Codable {
    let price: Double?
    let volume24h: Double?
    let volumeChange24h: Double?
    let percentChange1h: Double?
    let percentChange24h: Double?
    let percentChange7d: Double?
    let percentChange30d: Double?
    let percentChange60d: Double?
    let percentChange90d: Double?
    let marketCap: Double?
    let marketCapDominance: Double?
    let fullyDilutedMarketCap: Double?
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case price
        case volume24h = "volume_24h"
        case volumeChange24h = "volume_change_24h"
        case percentChange1h = "percent_change_1h"
        case percentChange24h = "percent_change_24h"
        case percentChange7d = "percent_change_7d"
        case percentChange30d = "percent_change_30d"
        case percentChange60d = "percent_change_60d"
        case percentChange90d = "percent_change_90d"
        case marketCap = "market_cap"
        case marketCapDominance = "market_cap_dominance"
        case fullyDilutedMarketCap = "fully_diluted_market_cap"
        case lastUpdated = "last_updated"
    }
}
