//
//  CoinDetailsVC.swift
//  CryptoApp
//
//  Smooth UI transitions with silent segment updates
//

import UIKit
import Combine

final class CoinDetailsVC: UIViewController {
    
    // MARK: - Properties
    
    private let coin: Coin
    private let viewModel: CoinDetailsVM
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    // FIXED: Prevent recursive updates during landscape synchronization
    private var isUpdatingFromLandscape = false
    
    // FIXED: Combine reactive state management
    private let selectedRange = CurrentValueSubject<String, Never>("24h")
    private let selectedChartType = CurrentValueSubject<ChartType, Never>(.line)
    private var cancellables = Set<AnyCancellable>()
    
    // UI state tracking
    private var lastChartUpdateTime: Date?
    private var isUserInteracting = false
    
    // MARK: - Optimization Properties
    private var isViewVisible = false
    private var refreshTimer: Timer? // Timer is properly managed separately
    
    // MARK: - Price Animation Support
    private var lastKnownPrice: String?
    
    // MARK: - Init
    
    init(coin: Coin) {
        self.coin = coin
        self.viewModel = CoinDetailsVM(coin: coin)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("🧹 CoinDetailsVC deinit - cleaning up resources for \(coin.symbol)")
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        bindViewModel()
        bindFilter()
        setupScrollDetection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        
        stopParentTimers()
        isViewVisible = true
        
        // Simple UI synchronization
        synchronizeUIWithCurrentState()
        
        startSmartAutoRefresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewVisible = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        resumeParentTimers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if isMovingFromParent || isBeingDismissed {
            viewModel.cancelAllRequests()
            print("🚪 Officially leaving coin details page - cancelled all API calls")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // BEST PRACTICE: Double-check synchronization after transition completes
        // Only needed if there was an animated transition
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.synchronizeUIWithCurrentState()
            }
        }
    }
    
    // Simple UI synchronization method
    private func synchronizeUIWithCurrentState() {
        // Update segment filter silently
        if let segmentCell = getSegmentCell() {
            segmentCell.setSelectedRangeSilently(selectedRange.value)
        }
        
        print("📱 UI synchronized: range=\(selectedRange.value), chartType=\(selectedChartType.value)")
    }
    
    // MARK: - Setup
    
    private func setupTableView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = coin.name
        navigationItem.largeTitleDisplayMode = .never
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 300
        
        tableView.register(InfoCell.self, forCellReuseIdentifier: "InfoCell")
        tableView.register(SegmentCell.self, forCellReuseIdentifier: "SegmentCell")
        tableView.register(ChartCell.self, forCellReuseIdentifier: "ChartCell")
        tableView.register(StatsCell.self, forCellReuseIdentifier: "StatsCell")

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupScrollDetection() {
        tableView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isUserInteracting = true
        case .ended, .cancelled:
            isUserInteracting = false
        default:
            break
        }
    }
    
    // MARK: - OPTIMIZED: Combine Bindings
    
    private func bindViewModel() {
        
        // Chart updates with throttling
        viewModel.chartPoints
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] newPoints in
                guard let self = self else { return }
                
                // Skip if user is interacting or no meaningful change
                guard !self.isUserInteracting,
                      self.shouldUpdateChart(newPoints: newPoints) else { return }
                
                self.updateChartCell(newPoints)
                self.lastChartUpdateTime = Date()
            }
            .store(in: &cancellables)
        
        // Loading state updates
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                if let chartCell = self.getChartCell() {
                    chartCell.updateLoadingState(isLoading)
                }
            }
            .store(in: &cancellables)
        
        // Error handling
        viewModel.errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] errorMessage in
                guard let self = self else { return }
                
                // Only show alerts for non-chart errors
                let isChartError = errorMessage.contains("chart") || 
                                   errorMessage.contains("data") || 
                                   errorMessage.contains("rate limit") ||
                                   errorMessage.contains("cooldown")
                
                if !isChartError {
                    self.showErrorAlert(message: errorMessage)
                }
            }
            .store(in: &cancellables)
        
        // Combined loading state for sophisticated UI updates
        viewModel.chartLoadingState
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] loadingState in
                guard let self = self, let chartCell = self.getChartCell() else { return }
                
                switch loadingState {
                case .loading:
                    chartCell.updateLoadingState(true)
                case .loaded:
                    chartCell.updateLoadingState(false)
                case .error:
                    chartCell.showErrorState("No chart data available")
                case .empty:
                    chartCell.updateLoadingState(false)
                }
            }
            .store(in: &cancellables)
        
        // Stats range updates
        viewModel.selectedStatsRange
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateStatsCell()
            }
            .store(in: &cancellables)
        
        // OHLC data updates for candlestick charts
        viewModel.ohlcData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newOHLCData in
                guard let self = self else { return }
                self.updateChartCellWithOHLC(newOHLCData)
            }
            .store(in: &cancellables)
        
        // 🌐 REAL-TIME COIN DATA: Listen for fresh coin data from SharedCoinDataManager
        viewModel.coinData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedCoin in
                guard let self = self else { return }
                self.updateInfoCellWithRealTimeData(updatedCoin)
                self.updateStatsCell() // Also update stats with fresh data
            }
            .store(in: &cancellables)
        
        // 💰 PRICE CHANGE ANIMATIONS: Listen for price change indicators
        viewModel.priceChange
            .receive(on: DispatchQueue.main)
            .compactMap { $0 } // Only process non-nil indicators
            .sink { [weak self] priceChange in
                guard let self = self else { return }
                self.animatePriceChange(priceChange)
            }
            .store(in: &cancellables)
    }
    
    // Simplified chart update logic
    private func shouldUpdateChart(newPoints: [Double]) -> Bool {
        // Skip if no data
        if newPoints.isEmpty { return false }
        
        // Skip if too frequent updates (throttled to 1 second by Combine)
        if let lastUpdate = lastChartUpdateTime,
           Date().timeIntervalSince(lastUpdate) < 1.0 {
            return false
        }
        
        return true
    }
    
    private func updateChartCell(_ points: [Double]) {
        guard let chartCell = getChartCell() else {
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            return
        }
        
        chartCell.updateChartData(points: points, ohlcData: nil, range: selectedRange.value)
    }
    
    private func updateChartCellWithOHLC(_ ohlcData: [OHLCData]) {
        guard let chartCell = getChartCell() else {
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            return
        }
        
        chartCell.updateChartData(points: nil, ohlcData: ohlcData, range: selectedRange.value)
    }
    
    private func getChartCell() -> ChartCell? {
        let chartIndexPath = IndexPath(row: 0, section: 2)
        
        guard chartIndexPath.section < tableView.numberOfSections,
              chartIndexPath.row < tableView.numberOfRows(inSection: chartIndexPath.section) else {
            return nil
        }
        
        return tableView.cellForRow(at: chartIndexPath) as? ChartCell
    }
    
    // MARK: - Filter Binding with Debouncing
    
    private func bindFilter() {
        // Debounced filter changes
        selectedRange
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] range in
                guard let self = self else { return }
                
                // Don't fetch data if this is a UI sync from landscape
                guard !self.isUpdatingFromLandscape else {
                    print("🔄 Skipping data fetch - updating from landscape sync")
                    return
                }
                
                print("⚡ Debounced filter change executing: \(range)")
                self.viewModel.fetchChartData(for: range)
            }
            .store(in: &cancellables)
        
        // Simple reactive UI binding
        selectedRange
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] range in
                guard let self = self else { return }
                
                // Use silent updates for programmatic changes
                if let segmentCell = self.getSegmentCell() {
                    segmentCell.setSelectedRangeSilently(range)
                }
                
                print("🔄 Filter UI updated to: \(range)")
            }
            .store(in: &cancellables)
        
        // Chart type changes
        selectedChartType
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] chartType in
                guard let self = self else { return }
                
                print("🔄 Chart type changed to: \(chartType)")
                
                // Update ViewModel
                self.viewModel.setChartType(chartType, for: self.selectedRange.value)
                
                // Update UI cells
                if let segmentCell = self.getSegmentCell() {
                    segmentCell.setChartType(chartType)
                }
                
                if let chartCell = self.getChartCell() {
                    chartCell.switchChartType(to: chartType)
                }
            }
            .store(in: &cancellables)
    }
    
    private func getSegmentCell() -> SegmentCell? {
        let segmentIndexPath = IndexPath(row: 0, section: 1)
        
        guard segmentIndexPath.section < tableView.numberOfSections,
              segmentIndexPath.row < tableView.numberOfRows(inSection: segmentIndexPath.section) else {
            return nil
        }
        
        return tableView.cellForRow(at: segmentIndexPath) as? SegmentCell
    }
    
    // MARK: - Smart Auto-Refresh
    
    private func startSmartAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.performSmartRefresh()
        }
    }
    
    private func performSmartRefresh() {
        guard isViewVisible && !isUserInteracting else {
            print("⏸️ Skipping auto-refresh: visible=\(isViewVisible), interacting=\(isUserInteracting)")
            return
        }
        
        print("🔄 Performing smart auto-refresh")
        
        // Refresh chart data
        viewModel.smartAutoRefresh(for: selectedRange.value)
        
        // Also refresh the price in InfoCell with animation
        // Note: This is a simplified approach since we don't have real-time price updates for individual coins
        // In a production app, you'd want to implement a proper price update mechanism
        refreshInfoCellPrice()
    }
    
    private func refreshInfoCellPrice() {
        // For demo purposes, we'll just trigger an animation on the current price
        // In reality, you'd fetch updated price data from an API
        let infoIndexPath = IndexPath(row: 0, section: 0)
        
        guard infoIndexPath.section < tableView.numberOfSections,
              let infoCell = tableView.cellForRow(at: infoIndexPath) as? InfoCell else {
            return
        }
        
        // For demonstration, simulate a small price change (this would be real data in production)
        if let currentPriceText = infoCell.priceLabel.text,
           let currentPrice = parsePrice(from: currentPriceText) {
            
            // Simulate a small price fluctuation (±0.1% to ±2%)
            let changePercent = Double.random(in: -0.02...0.02)
            let newPrice = currentPrice * (1 + changePercent)
            let newPriceString = formatPrice(newPrice)
            
            // Trigger animation
            infoCell.priceLabel.text = newPriceString
            let isPositive = newPrice > currentPrice
            infoCell.flashPrice(isPositive: isPositive)
        }
    }
    
    private func parsePrice(from priceString: String) -> Double? {
        let cleanedString = priceString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(cleanedString)
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        
        if let formattedNumber = formatter.string(from: NSNumber(value: price)) {
            return "$\(formattedNumber)"
        } else {
            return "$\(String(format: "%.2f", price))"
        }
    }
    
    // MARK: - Real-Time Data Updates
    
    private func updateInfoCellWithRealTimeData(_ coin: Coin) {
        let infoIndexPath = IndexPath(row: 0, section: 0)
        
        guard infoIndexPath.section < tableView.numberOfSections,
              let infoCell = tableView.cellForRow(at: infoIndexPath) as? InfoCell else {
            // If cell is not visible, just update the stored price
            lastKnownPrice = coin.priceString
            return
        }
        
        // Get updated 24h price change data
        let percentChange24h = coin.quote?["USD"]?.percentChange24h ?? 0.0
        let currentPrice = coin.quote?["USD"]?.price ?? 0.0
        let priceChange24h = (percentChange24h / 100.0) * currentPrice / (1 + (percentChange24h / 100.0))
        
        // Update cell with fresh data including permanent price change indicator
        infoCell.configure(name: coin.name, rank: coin.cmcRank, price: coin.priceString, priceChange: priceChange24h, percentageChange: percentChange24h)
        lastKnownPrice = coin.priceString
        
        print("💰 CoinDetails: Updated InfoCell with fresh data for \(coin.symbol)")
    }
    
    private func animatePriceChange(_ priceChange: PriceChangeIndicator) {
        let infoIndexPath = IndexPath(row: 0, section: 0)
        
        guard infoIndexPath.section < tableView.numberOfSections,
              let infoCell = tableView.cellForRow(at: infoIndexPath) as? InfoCell else {
            return
        }
        
        // Determine animation color based on price direction
        let isPositive = priceChange.direction == .up
        
        // Trigger price animation
        infoCell.flashPrice(isPositive: isPositive)
        
        // Update the price change indicator with correct sign based on direction
        let signedPriceChange = priceChange.amount * (isPositive ? 1 : -1)
        let signedPercentageChange = priceChange.percentage * (isPositive ? 1 : -1)
        
        infoCell.updatePriceChangeIndicator(priceChange: signedPriceChange, percentageChange: signedPercentageChange)
        
        print("🎨 CoinDetails: Animated price change - \(priceChange.direction) by $\(String(format: "%.2f", signedPriceChange))")
    }
    

    
    private func updateStatsCell() {
        let statsIndexPath = IndexPath(row: 0, section: 3)
        
        guard statsIndexPath.section < tableView.numberOfSections else {
            print("⚠️ Stats section doesn't exist yet")
            return
        }
        
        guard let statsCell = tableView.cellForRow(at: statsIndexPath) as? StatsCell else {
            if statsIndexPath.section < tableView.numberOfSections {
                tableView.reloadSections(IndexSet(integer: 3), with: .none)
            }
            return
        }
        
        statsCell.configure(viewModel.currentStats, selectedRange: viewModel.currentSelectedStatsRange) { [weak self] selectedRange in
            print("📊 Selected stats filter: \(selectedRange)")
            self?.viewModel.updateStatsRange(selectedRange)
        }
    }
    
    private func showErrorAlert(message: String) {
        // FIXED: Only show alert if view is in window hierarchy
        guard isViewLoaded,
              view.window != nil,
              presentedViewController == nil else {
            print("📊 Skipping error alert - view not in hierarchy or modal already presented")
            return
        }
        
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Landscape Chart
    
    private func presentLandscapeChart() {
        let currentPoints = viewModel.currentChartPoints
        let currentOHLCData = viewModel.currentOHLCData
        let currentRange = selectedRange.value
        let currentChartType = selectedChartType.value
        
        let landscapeVC = LandscapeChartViewController(
            coin: coin,
            selectedRange: currentRange,
            selectedChartType: currentChartType,
            points: currentPoints,
            ohlcData: currentOHLCData,
            viewModel: viewModel
        )
        
        landscapeVC.onStateChanged = { [weak self] newRange, newChartType in
            guard let self = self else { return }
            
            print("📊 Synchronizing state from landscape: range=\(newRange), chartType=\(newChartType)")
            
            // Simple state synchronization
            self.isUpdatingFromLandscape = true
            
            // Update state immediately
            if self.selectedRange.value != newRange {
                print("📊 Range changed: \(self.selectedRange.value) → \(newRange)")
                self.selectedRange.send(newRange)
            }
            
            if self.selectedChartType.value != newChartType {
                print("📊 Chart type changed: \(self.selectedChartType.value) → \(newChartType)")
                self.selectedChartType.send(newChartType)
            }
            
            // Clear flag
            self.isUpdatingFromLandscape = false
            print("🔄 Landscape sync completed")
        }
        
        landscapeVC.modalPresentationStyle = .fullScreen
        landscapeVC.modalTransitionStyle = .crossDissolve
        
        present(landscapeVC, animated: true)
    }
    
    // MARK: - Parent Timer Management
    
    private func stopParentTimers() {
        if let parentNav = navigationController,
           let coinListVC = parentNav.viewControllers.first(where: { $0 is CoinListVC }) as? CoinListVC {
            coinListVC.stopAutoRefreshFromChild()
            coinListVC.stopWatchlistTimersFromChild()
        }
        
        if let parentNav = navigationController,
           let searchVC = parentNav.viewControllers.first(where: { $0 is SearchVC }) as? SearchVC {
            searchVC.stopBackgroundOperationsFromChild()
        }
    }
    
    private func resumeParentTimers() {
        if let parentNav = navigationController,
           let coinListVC = parentNav.viewControllers.first(where: { $0 is CoinListVC }) as? CoinListVC {
            coinListVC.resumeAutoRefreshFromChild()
            coinListVC.resumeWatchlistTimersFromChild()
        }
        
        if let parentNav = navigationController,
           let searchVC = parentNav.viewControllers.first(where: { $0 is SearchVC }) as? SearchVC {
            searchVC.resumeBackgroundOperationsFromChild()
        }
    }
}

// MARK: - UITableViewDataSource

extension CoinDetailsVC: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4 // Info, Segment, Chart, Stats
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1 // Each section has one cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        case 0: // Info section
            let cell = tableView.dequeueReusableCell(withIdentifier: "InfoCell", for: indexPath) as! InfoCell
            let currentCoin = viewModel.currentCoin
            
            // Get 24h price change data from the coin
            let percentChange24h = currentCoin.quote?["USD"]?.percentChange24h ?? 0.0
            let currentPrice = currentCoin.quote?["USD"]?.price ?? 0.0
            let priceChange24h = (percentChange24h / 100.0) * currentPrice / (1 + (percentChange24h / 100.0))
            
            // Configure with permanent price change indicator
            cell.configure(name: currentCoin.name, rank: currentCoin.cmcRank, price: currentCoin.priceString, priceChange: priceChange24h, percentageChange: percentChange24h)
            
            // Initialize price tracking for animations
            if lastKnownPrice == nil {
                lastKnownPrice = currentCoin.priceString
            }
            
            cell.selectionStyle = .none
            return cell
            
        case 1: // Filter section (Segmented control)
            let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentCell
            
            // Configure without animations
            UIView.performWithoutAnimation {
                cell.configure(items: ["24h", "7d", "30d", "All"], chartType: selectedChartType.value) { [weak self] range in
                    guard let self = self else { return }
                    
                    guard !self.isUpdatingFromLandscape else {
                        print("🔄 Ignoring segment selection - updating from landscape")
                        return
                    }
                    
                    print("🔄 Manual filter selection: \(range)")
                    self.selectedRange.send(range)
                }
                
                cell.setSelectedRangeSilently(selectedRange.value)
            }
            
            cell.onChartTypeToggle = { [weak self] chartType in
                self?.selectedChartType.send(chartType)
            }
            
            cell.onLandscapeToggle = { [weak self] in
                self?.presentLandscapeChart()
            }
            
            cell.selectionStyle = .none
            return cell
            
        case 2: // Chart section
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChartCell", for: indexPath) as! ChartCell
            
            // Configure with both line and OHLC data
            cell.configure(points: viewModel.currentChartPoints, range: selectedRange.value)
            cell.configure(ohlcData: viewModel.currentOHLCData, range: selectedRange.value)
            
            // Switch to current chart type
            cell.switchChartType(to: selectedChartType.value)
            
            cell.selectionStyle = .none
            return cell
            
        case 3: // Stats section
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatsCell", for: indexPath) as! StatsCell
            cell.configure(viewModel.currentStats, selectedRange: viewModel.currentSelectedStatsRange) { [weak self] selectedRange in
                print("📊 Selected stats filter: \(selectedRange)")
                self?.viewModel.updateStatsRange(selectedRange)
            }
            cell.selectionStyle = .none
            return cell

        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate

extension CoinDetailsVC: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return UITableView.automaticDimension
        case 1: return 40
        case 2: return 300
        case 3: return UITableView.automaticDimension
        default: return 44
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 100
        case 1: return 40
        case 2: return 300
        case 3: return 200
        default: return 44
        }
    }
}


