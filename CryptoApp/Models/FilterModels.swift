//
//  FilterModels.swift
//  CryptoApp
//
//  Created by AI Assistant on 7/7/25.
//

import Foundation

// MARK: - Price Change Filter Types

enum PriceChangeFilter: String, CaseIterable {
    case oneHour = "1h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    
    var displayName: String {
        switch self {
        case .oneHour:
            return "1 Hour"
        case .twentyFourHours:
            return "24 Hours"
        case .sevenDays:
            return "7 Days"
        case .thirtyDays:
            return "30 Days"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .oneHour:
            return "1h"
        case .twentyFourHours:
            return "24h"
        case .sevenDays:
            return "7d"
        case .thirtyDays:
            return "30d"
        }
    }
    
    var sortParameter: String {
        switch self {
        case .oneHour:
            return "percent_change_1h"
        case .twentyFourHours:
            return "percent_change_24h"
        case .sevenDays:
            return "percent_change_7d"
        case .thirtyDays:
            return "percent_change_30d"
        }
    }
}

// MARK: - Top Coins Filter Types

enum TopCoinsFilter: Int, CaseIterable {
    case top100 = 100
    case top200 = 200
    case top500 = 500
    case all = 5000 // CoinMarketCap practical limit
    
    var displayName: String {
        switch self {
        case .top100:
            return "Top 100"
        case .top200:
            return "Top 200"
        case .top500:
            return "Top 500"
        case .all:
            return "All Coins"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .top100:
            return "100"
        case .top200:
            return "200"
        case .top500:
            return "500"
        case .all:
            return "All"
        }
    }
}

// MARK: - Combined Filter State

struct FilterState: Equatable {
    let priceChangeFilter: PriceChangeFilter
    let topCoinsFilter: TopCoinsFilter
    
    // Default state matching CoinMarketCap defaults
    static let defaultState = FilterState(
        priceChangeFilter: .twentyFourHours,
        topCoinsFilter: .top100
    )
    
    // Display text for buttons
    var priceChangeDisplayText: (title: String, subtitle: String) {
        return (
            title: priceChangeFilter.shortDisplayName + "%",
            subtitle: ""
        )
    }
    
    var topCoinsDisplayText: (title: String, subtitle: String) {
        return (
            title: topCoinsFilter == .all ? "All" : "Top " + topCoinsFilter.shortDisplayName,
            subtitle: ""
        )
    }
}

// MARK: - Filter Options Protocol

protocol FilterOption {
    var displayName: String { get }
    var isSelected: Bool { get set }
}

// MARK: - Filter Option Implementations

struct PriceChangeFilterOption: FilterOption {
    let filter: PriceChangeFilter
    var isSelected: Bool
    
    var displayName: String {
        return filter.displayName
    }
}

struct TopCoinsFilterOption: FilterOption {
    let filter: TopCoinsFilter
    var isSelected: Bool
    
    var displayName: String {
        return filter.displayName
    }
}

// MARK: - Filter Type Enum

enum FilterType {
    case priceChange
    case topCoins
    
    var title: String {
        switch self {
        case .priceChange:
            return "Price Change Period"
        case .topCoins:
            return "Number of Coins"
        }
    }
} 