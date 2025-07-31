//
//  SharedCoinDataManager.swift
//  CryptoApp
//
//  Created by AI Assistant on 1/8/25.
//

import Foundation
import Combine

/// Shared data manager that ensures price consistency across all ViewModels
final class SharedCoinDataManager: SharedCoinDataManagerProtocol {
    
    // MARK: - Properties
    
    private let coinManager: CoinManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 30.0
    private var updateTimer: Timer?
    
    // Single source of truth for all coin data
    private let coinDataSubject = CurrentValueSubject<[Coin], Never>([])
    private let errorSubject = PassthroughSubject<Error, Never>()
    private var lastUpdateTime: Date?
    private var isUpdating = false
    
    // MARK: - SharedCoinDataManagerProtocol Conformance
    
    /// Publisher that emits the current list of all coins
    var allCoins: AnyPublisher<[Coin], Never> {
        coinDataSubject.eraseToAnyPublisher()
    }
    
    /// Publisher that emits errors from shared data fetching
    var errors: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    /// Get current coins synchronously
    var currentCoins: [Coin] {
        coinDataSubject.value
    }
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts CoinManagerProtocol for:
     * - Better testability with mock implementations
     * - Flexibility to swap implementations
     * - Cleaner separation of concerns
     * 
     * Falls back to default CoinManager for backward compatibility
     */
    init(coinManager: CoinManagerProtocol) {
        self.coinManager = coinManager
        startAutoUpdate()
    }
    
    deinit {
        stopAutoUpdate()
    }
    
    // MARK: - SharedCoinDataManagerProtocol Methods
    
    /// Start the shared data updates
    func startAutoUpdate() {
        stopAutoUpdate() // Ensure no duplicate timers
        
        // Initial fetch
        fetchSharedData()
        
        // Set up periodic updates with proper run loop
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            print("⏰ SharedCoinDataManager: Timer fired - fetching data...")
            self?.fetchSharedData()
        }
        
        // Add to main run loop to ensure it runs in background
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🌐 SharedCoinDataManager: Started shared updates (30s intervals)")
    }
    
    /// Stop the shared data updates
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
        print("🌐 SharedCoinDataManager: Stopped shared updates")
    }
    
    /// Force an immediate update
    func forceUpdate() {
        fetchSharedData()
    }
    
    /// Get coins filtered by IDs (for watchlist)
    func getCoinsForIds(_ ids: [Int]) -> [Coin] {
        let idSet = Set(ids)
        return currentCoins.filter { idSet.contains($0.id) }
    }
    
    // MARK: - Private Methods
    
    private func fetchSharedData() {
        guard !isUpdating else { 
            print("🚫 SharedCoinDataManager: Update already in progress")
            return 
        }
        
        isUpdating = true
        lastUpdateTime = Date()
        
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("🔄 SharedCoinDataManager: Fetching fresh price data at \(timeString)...")
        
        // If we already have coins, update their prices with fresh quotes
        if !currentCoins.isEmpty {
            let coinIds = Array(currentCoins.prefix(200).map { $0.id }) // Update top 200 coins
            
            coinManager.getQuotes(for: coinIds, convert: "USD", priority: .high)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        self?.isUpdating = false
                        if case .failure(let error) = completion {
                            print("❌ SharedCoinDataManager: Failed to fetch quotes - \(error)")
                            self?.errorSubject.send(error)
                        }
                    },
                    receiveValue: { [weak self] updatedQuotes in
                        guard let self = self else { return }
                        
                        self.isUpdating = false
                        
                        // Update existing coins with fresh quotes
                        var updatedCoins = self.currentCoins
                        for i in 0..<updatedCoins.count {
                            let coinId = updatedCoins[i].id
                            if let newQuote = updatedQuotes[coinId] {
                                updatedCoins[i].quote?["USD"] = newQuote
                            }
                        }
                        
                        self.coinDataSubject.send(updatedCoins)
                        
                        print("✅ SharedCoinDataManager: Updated prices for \(updatedQuotes.count) coins with FRESH quotes")
                        
                        // Log verification that market cap data is present
                        if let btc = updatedCoins.first(where: { $0.symbol == "BTC" }),
                           let quote = btc.quote?["USD"],
                           let marketCap = quote.marketCap {
                            print("📊 SharedCoinDataManager: BTC updated with market cap: $\(String(format: "%.0f", marketCap))")
                        }
                    }
                )
                .store(in: &cancellables)
        } else {
            // First time: get initial coin list
            coinManager.getTopCoins(
                limit: 500, // Get enough to cover all possible coins
                convert: "USD",
                start: 1,
                sortType: "market_cap",
                sortDir: "desc",
                priority: .high
            )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isUpdating = false
                    if case .failure(let error) = completion {
                        print("❌ SharedCoinDataManager: Failed to fetch initial data - \(error)")
                        self?.errorSubject.send(error)
                    }
                },
                receiveValue: { [weak self] coins in
                    guard let self = self else { return }
                    
                    self.isUpdating = false
                    self.coinDataSubject.send(coins)
                    
                    print("✅ SharedCoinDataManager: Initial load with \(coins.count) coins")
                    
                    // 🖼️ FETCH LOGOS: Start downloading logos for top coins (first 50)
                    let topCoins = Array(coins.prefix(50))
                    let logoIds = topCoins.map { $0.id }
                    self.coinManager.getCoinLogos(forIDs: logoIds, priority: .low)
                        .sink { _ in
                            // Logos are cached automatically by CoinService
                            print("🖼️ SharedCoinDataManager: Logo fetch completed for top 50 coins")
                        }
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
        }
    }
} 