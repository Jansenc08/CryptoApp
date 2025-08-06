//
//  CoinDetailsVC.swift
//  CryptoApp
//
//  Smooth UI transitions with silent segment updates
//

import UIKit
import Combine

final class CoinDetailsVC: UIViewController, ChartSettingsDelegate {
    
    // MARK: - Properties
    
    private let coin: Coin
    private let viewModel: CoinDetailsVM
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let watchlistManager: WatchlistManagerProtocol
    
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
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts a Coin and uses dependency container for ViewModel creation.
     * Provides better testability and modularity.
     */
    init(coin: Coin) {
        self.coin = coin
        self.viewModel = Dependencies.container.coinDetailsViewModel(coin: coin)
        self.watchlistManager = Dependencies.container.watchlistManager()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        AppLogger.ui("CoinDetailsVC deinit - cleaning up resources for \(coin.symbol)")
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        title = coin.symbol.uppercased()
        
        // Add filter/settings button to navigation bar
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    @objc private func settingsButtonTapped() {
        let settingsVC = ChartSettingsVC()
        settingsVC.delegate = self
        settingsVC.configure(
            smoothingEnabled: viewModel.smoothingEnabled,
            smoothingType: viewModel.currentSmoothingType
        )
        
        // Embed in navigation controller
        let navigationController = UINavigationController(rootViewController: settingsVC)
        
        // Present as modal sheet
        if let presentationController = navigationController.presentationController as? UISheetPresentationController {
            presentationController.detents = [.medium(), .large()]
            presentationController.prefersGrabberVisible = true
        }
        
        present(navigationController, animated: true)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
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
        
        // Clear any previous error states to prevent flashing
        viewModel.clearPreviousStates()
        
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
            AppLogger.ui("Officially leaving coin details page - cancelled all API calls")
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
        
        AppLogger.ui("UI synchronized: range=\(selectedRange.value), chartType=\(selectedChartType.value)")
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
        tableView.register(PriceChangeOverviewCell.self, forCellReuseIdentifier: "PriceChangeOverviewCell")
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
        
        // Chart updates with throttling and debouncing to reduce flashing
        viewModel.chartPoints
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Debounce rapid changes
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
                case .error(let retryInfo):
                    chartCell.showRetryableError(retryInfo)
                case .nonRetryableError(let message):
                    chartCell.showNonRetryableError(message)
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
        
        // Stats updates with reactive high/low data
        viewModel.stats.sinkForUI(
            { [weak self] _ in
                self?.updateStatsCell()
            },
            storeIn: &cancellables
        )
        
        // OHLC data updates for candlestick charts and Low/High section with debouncing
        viewModel.ohlcData
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Debounce rapid changes
            .sink { [weak self] newOHLCData in
                guard let self = self else { return }
                self.updateChartCellWithOHLC(newOHLCData)
                // Update StatsCell when OHLC data becomes available for Low/High section
                if !newOHLCData.isEmpty {
                    AppLogger.data("[Low/High] OHLC data loaded: \(newOHLCData.count) candles - refreshing StatsCell")
                    DispatchQueue.main.async {
                        self.updateStatsCell()
                    }
                } else {
                    AppLogger.data("[Low/High] OHLC data is empty - Low/High section won't show", level: .warning)
                }
            }
            .store(in: &cancellables)
        
        // 🌐 REAL-TIME COIN DATA: Listen for fresh coin data from SharedCoinDataManager
        viewModel.coinData.sinkForUI(
            { [weak self] updatedCoin in
                guard let self = self else { return }
                self.updateInfoCellWithRealTimeData(updatedCoin)
                self.updatePriceChangeOverviewCell(updatedCoin) // Update price change overview
                self.updateStatsCell() // Also update stats with fresh data
            },
            storeIn: &cancellables
        )
        
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
        
        // ATOMIC UPDATE: Combine data update + settings application to prevent double flash
        chartCell.updateChartDataWithSettings(
            points: points, 
            ohlcData: nil, 
            range: selectedRange.value,
            settings: getCurrentChartSettings()
        )
    }
    
    private func updateChartCellWithOHLC(_ ohlcData: [OHLCData]) {
        guard let chartCell = getChartCell() else {
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            return
        }
        
        // ATOMIC UPDATE: Combine OHLC data update + settings application to prevent double flash
        chartCell.updateChartDataWithSettings(
            points: nil, 
            ohlcData: ohlcData, 
            range: selectedRange.value,
            settings: getCurrentChartSettings()
        )
    }
    
    private func getChartCell() -> ChartCell? {
        let chartIndexPath = IndexPath(row: 0, section: 2)
        
        guard chartIndexPath.section < tableView.numberOfSections,
              chartIndexPath.row < tableView.numberOfRows(inSection: chartIndexPath.section) else {
            return nil
        }
        
        return tableView.cellForRow(at: chartIndexPath) as? ChartCell
    }
    
    // MARK: - Retry Handling
    
    private func handleChartRetry() {
        AppLogger.ui("Chart retry requested by user")
        
        // Trigger retry in the view model
        viewModel.retryAllChartData()
        
        // Provide haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
    }
    
    // MARK: - Filter Binding with Debouncing
    
    private func bindFilter() {
        // Debounced filter changes (including initial load)
        selectedRange
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .debounce(for: .seconds(0.1), scheduler: DispatchQueue.main) // Shorter debounce for initial load
            .sink { [weak self] range in
                guard let self = self else { return }
                
                // Don't fetch data if this is a UI sync from landscape
                guard !self.isUpdatingFromLandscape else {
                    AppLogger.ui("Skipping data fetch - updating from landscape sync")
                    return
                }
                
                AppLogger.ui("Filter change executing: \(range)")
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
                
                AppLogger.ui("Filter UI updated to: \(range)")
            }
            .store(in: &cancellables)
        
        // Chart type changes (UI only - data fetching handled by selectedRange)
        selectedChartType
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] chartType in
                guard let self = self else { return }
                
                AppLogger.ui("Chart type changed to: \(chartType)")
                
                // Update ViewModel (this uses cached data, doesn't fetch)
                self.viewModel.setChartType(chartType, for: self.selectedRange.value)
                
                // Update UI cells
                if let segmentCell = self.getSegmentCell() {
                    segmentCell.setChartType(chartType)
                }
                
                if let chartCell = self.getChartCell() {
                    chartCell.switchChartType(to: chartType)
                    
                    // ATOMIC: Apply settings without triggering multiple redraws
                    chartCell.applySettingsAtomically(self.getCurrentChartSettings())
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
            AppLogger.performance("Skipping auto-refresh: visible=\(isViewVisible), interacting=\(isUserInteracting)")
            return
        }
        
        AppLogger.performance("Performing smart auto-refresh")
        
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
        
        // Update cell with fresh data including permanent price change indicator and watchlist state
        let isInWatchlist = watchlistManager.isInWatchlist(coinId: coin.id)
        infoCell.configure(
            name: coin.name,
            rank: coin.cmcRank,
            price: coin.priceString,
            priceChange: priceChange24h,
            percentageChange: percentChange24h,
            isInWatchlist: isInWatchlist
        ) { [weak self] isNowInWatchlist in
            self?.handleWatchlistToggle(isNowInWatchlist: isNowInWatchlist)
        }
        lastKnownPrice = coin.priceString
        
        AppLogger.price("CoinDetails: Updated InfoCell with fresh data for \(coin.symbol)")
    }
    
    // MARK: - Price Change Overview Updates
    
    private func updatePriceChangeOverviewCell(_ coin: Coin) {
        let priceChangeIndexPath = IndexPath(row: 0, section: 3)
        
        guard priceChangeIndexPath.section < tableView.numberOfSections,
              let priceChangeCell = tableView.cellForRow(at: priceChangeIndexPath) as? PriceChangeOverviewCell else {
            // If cell is not visible, it will be updated when it becomes visible
            return
        }
        
        // Update cell with fresh data
        priceChangeCell.configure(with: coin)
        
        AppLogger.price("CoinDetails: Updated PriceChangeOverviewCell with fresh data for \(coin.symbol)")
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
        
        AppLogger.price("CoinDetails: Animated price change - \(priceChange.direction) by $\(String(format: "%.2f", signedPriceChange))")
    }
    
    // MARK: - Watchlist Management
    
    private func handleWatchlistToggle(isNowInWatchlist: Bool) {
        if isNowInWatchlist {
            // Add to watchlist
            watchlistManager.addToWatchlist(coin, logoURL: nil)
            AppLogger.ui("Added \(coin.symbol) to watchlist")
            
            // Show success feedback
            showWatchlistFeedback(message: "Added to Watchlist", isPositive: true)
        } else {
            // Remove from watchlist
            watchlistManager.removeFromWatchlist(coinId: coin.id)
            AppLogger.ui("Removed \(coin.symbol) from watchlist")
            
            // Show feedback
            showWatchlistFeedback(message: "Removed from Watchlist", isPositive: false)
        }
    }
    
    private func showWatchlistFeedback(message: String, isPositive: Bool) {
        // Create a simple feedback view
        let feedbackView = UIView()
        feedbackView.backgroundColor = isPositive ? UIColor.systemGreen.withAlphaComponent(0.9) : UIColor.systemRed.withAlphaComponent(0.9)
        feedbackView.layer.cornerRadius = 8
        feedbackView.translatesAutoresizingMaskIntoConstraints = false
        
        let feedbackLabel = UILabel()
        feedbackLabel.text = message
        feedbackLabel.textColor = .white
        feedbackLabel.font = .systemFont(ofSize: 14, weight: .medium)
        feedbackLabel.textAlignment = .center
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        
        feedbackView.addSubview(feedbackLabel)
        view.addSubview(feedbackView)
        
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: feedbackView.centerXAnchor),
            feedbackLabel.centerYAnchor.constraint(equalTo: feedbackView.centerYAnchor),
            feedbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: feedbackView.leadingAnchor, constant: 12),
            feedbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: feedbackView.trailingAnchor, constant: -12),
            
            feedbackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            feedbackView.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Animate in
        feedbackView.alpha = 0
        feedbackView.transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            feedbackView.alpha = 1
            feedbackView.transform = .identity
        } completion: { _ in
            // Animate out after 2 seconds
            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseIn) {
                feedbackView.alpha = 0
                feedbackView.transform = CGAffineTransform(translationX: 0, y: -20)
            } completion: { _ in
                feedbackView.removeFromSuperview()
            }
        }
    }

    
    private func updateStatsCell() {
        guard let statsCell = tableView.cellForRow(at: IndexPath(row: 0, section: 4)) as? StatsCell else {
            return
        }
        
        // Use the current stats which includes all fields
        let currentStatsData = viewModel.currentStats
        
        statsCell.configure(currentStatsData, selectedRange: viewModel.currentSelectedStatsRange) { [weak self] selectedRange in
            self?.viewModel.updateStatsRange(selectedRange)
        }
    }
    
    private func showErrorAlert(message: String) {
        // FIXED: Only show alert if view is in window hierarchy
        guard isViewLoaded,
              view.window != nil,
              presentedViewController == nil else {
            AppLogger.ui("Skipping error alert - view not in hierarchy or modal already presented", level: .warning)
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
        
        let landscapeVC = LandscapeChartVC(
            coin: coin,
            selectedRange: currentRange,
            selectedChartType: currentChartType,
            points: currentPoints,
            ohlcData: currentOHLCData,
            viewModel: viewModel
        )
        
        landscapeVC.onStateChanged = { [weak self] newRange, newChartType in
            guard let self = self else { return }
            
            AppLogger.ui("Synchronizing state from landscape: range=\(newRange), chartType=\(newChartType)")
            
            // Simple state synchronization
            self.isUpdatingFromLandscape = true
            
            // Update state immediately
            if self.selectedRange.value != newRange {
                AppLogger.ui("Range changed: \(self.selectedRange.value) → \(newRange)")
                self.selectedRange.send(newRange)
            }
            
            if self.selectedChartType.value != newChartType {
                AppLogger.ui("Chart type changed: \(self.selectedChartType.value) → \(newChartType)")
                self.selectedChartType.send(newChartType)
            }
            
            // Clear flag
            self.isUpdatingFromLandscape = false
            AppLogger.ui("Landscape sync completed")
        }
        
        landscapeVC.modalPresentationStyle = .fullScreen
        landscapeVC.modalTransitionStyle = .crossDissolve
        
        present(landscapeVC, animated: true)
    }
    

    
    // MARK: - ChartSettingsDelegate
    
    func smoothingSettingsChanged(enabled: Bool, type: ChartSmoothingHelper.SmoothingType) {
        viewModel.setSmoothingEnabled(enabled)
        viewModel.setSmoothingType(type)
    }
    
    func chartSettingsDidUpdate() {
        // Update chart with new settings
        guard let chartCell = getChartCell() else { return }
        applyChartSettings(to: chartCell)
    }
    
    func technicalIndicatorsSettingsChanged(_ settings: TechnicalIndicators.IndicatorSettings) {
        // Apply technical indicators to the current chart (candlestick only)
        guard let chartCell = getChartCell() else { return }
        
        // Get current color theme
        let themeRawValue = UserDefaults.standard.string(forKey: "ChartColorTheme") ?? "classic"
        let theme = ChartColorTheme(rawValue: themeRawValue) ?? .classic
        
        // DEBUG: Log current chart type and settings
        AppLogger.ui("Applying technical indicators - Chart type: \(selectedChartType.value.rawValue)")
        AppLogger.ui("Settings - SMA: \(settings.showSMA), EMA: \(settings.showEMA), RSI: \(settings.showRSI)")
        
        // Apply indicators using the public method
        chartCell.applyTechnicalIndicators(settings, theme: theme)
    }
    

    
    func volumeSettingsChanged(showVolume: Bool) {
        // Update chart cell with new volume settings
        guard let chartCell = getChartCell() else {
            return
        }
        
        // Apply volume settings to chart cell
        chartCell.updateVolumeSettings(showVolume: showVolume)
        
        // If we don't have any data yet, trigger initial data load
        // This ensures the chart loads data when volume settings are changed on first app load
        if viewModel.currentChartPoints.isEmpty && viewModel.currentOHLCData.isEmpty {
            AppLogger.chart("🔊 Volume settings changed but no chart data available - triggering initial load")
            // Trigger data refresh for current range
            selectedRange.value = selectedRange.value // This will trigger data loading
        }
    }
    
    // MARK: - Chart Settings Application
    
    /// Gets current chart settings as a dictionary for atomic updates
    private func getCurrentChartSettings() -> [String: Any] {
        // Load volume settings to include in atomic updates
        let indicatorSettings = TechnicalIndicators.loadIndicatorSettings()
        
        return [
            "gridEnabled": UserDefaults.standard.bool(forKey: "ChartGridLinesEnabled"),
            "labelsEnabled": UserDefaults.standard.bool(forKey: "ChartPriceLabelsEnabled"),
            "autoScaleEnabled": UserDefaults.standard.bool(forKey: "ChartAutoScaleEnabled"),
            "colorTheme": UserDefaults.standard.string(forKey: "ChartColorTheme") ?? "classic",
            "lineThickness": UserDefaults.standard.double(forKey: "ChartLineThickness"),
            "animationSpeed": UserDefaults.standard.double(forKey: "ChartAnimationSpeed"),
            // Include volume settings for persistence
            "showVolume": indicatorSettings.showVolume
        ]
    }
    
    /// Applies all chart settings to the given chart cell
    /// This ensures settings persist across time range changes and chart type switches
    private func applyChartSettings(to chartCell: ChartCell) {
        // Apply visual settings
        let gridEnabled = UserDefaults.standard.bool(forKey: "ChartGridLinesEnabled")
        chartCell.toggleGridLines(gridEnabled)
        
        let labelsEnabled = UserDefaults.standard.bool(forKey: "ChartPriceLabelsEnabled")
        chartCell.togglePriceLabels(labelsEnabled)
        
        let autoScaleEnabled = UserDefaults.standard.bool(forKey: "ChartAutoScaleEnabled")
        chartCell.toggleAutoScale(autoScaleEnabled)
        
        // Apply appearance settings
        let themeRawValue = UserDefaults.standard.string(forKey: "ChartColorTheme") ?? "classic"
        if let theme = ChartColorTheme(rawValue: themeRawValue) {
            chartCell.applyColorTheme(theme)
        }
        
        let thickness = UserDefaults.standard.double(forKey: "ChartLineThickness")
        if thickness > 0 {
            chartCell.updateLineThickness(thickness)
        }
        
        let animationSpeed = UserDefaults.standard.double(forKey: "ChartAnimationSpeed")
        chartCell.setAnimationSpeed(animationSpeed)
        
        // Apply volume settings
        let indicatorSettings = TechnicalIndicators.loadIndicatorSettings()
        chartCell.updateVolumeSettings(showVolume: indicatorSettings.showVolume)
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
        return 5 // Info, Segment, Chart, PriceChangeOverview, Stats
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
            
            // Configure with permanent price change indicator and watchlist functionality
            let isInWatchlist = watchlistManager.isInWatchlist(coinId: currentCoin.id)
            cell.configure(
                name: currentCoin.name,
                rank: currentCoin.cmcRank,
                price: currentCoin.priceString,
                priceChange: priceChange24h,
                percentageChange: percentChange24h,
                isInWatchlist: isInWatchlist
            ) { [weak self] isNowInWatchlist in
                self?.handleWatchlistToggle(isNowInWatchlist: isNowInWatchlist)
            }
            
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
                        AppLogger.ui("Ignoring segment selection - updating from landscape")
                        return
                    }
                    
                    AppLogger.ui("Manual filter selection: \(range)")
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
            
            // ATOMIC: Apply chart settings after configuration to prevent double redraw
            cell.applySettingsAtomically(getCurrentChartSettings())
            
            // Apply volume settings explicitly
            let indicatorSettings = TechnicalIndicators.loadIndicatorSettings()
            cell.updateVolumeSettings(showVolume: indicatorSettings.showVolume)
            
            // Set up retry callback
            cell.onRetryRequested = { [weak self] in
                self?.handleChartRetry()
            }
            
            cell.selectionStyle = .none
            return cell
            
        case 3: // Price Change Overview section
            let cell = tableView.dequeueReusableCell(withIdentifier: "PriceChangeOverviewCell", for: indexPath) as! PriceChangeOverviewCell
            let currentCoin = viewModel.currentCoin
            cell.configure(with: currentCoin)
            cell.selectionStyle = .none
            return cell
            
        case 4: // Stats section
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatsCell", for: indexPath) as! StatsCell
            cell.configure(viewModel.currentStats, selectedRange: viewModel.currentSelectedStatsRange) { [weak self] selectedRange in
                AppLogger.ui("Selected stats filter: \(selectedRange)")
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
        case 1: // Segment control section - ensure minimum height for buttons
            return 76
        case 2: // Chart section
            return 440 // Fixed height for chart section: 250 (main) + 80 (volume) + 110 (spacing/margins/padding)
        default:
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 2: // Chart section
            return 440 // Estimated: 250 (main) + 80 (volume) + 110 (spacing)
        default:
            return UITableView.automaticDimension
        }
    }
}


