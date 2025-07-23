import UIKit
import Combine

final class CoinDetailsVC: UIViewController {
    
    // MARK: - Properties

    private let coin: Coin
    private let viewModel: CoinDetailsVM
    private let selectedRange = CurrentValueSubject<String, Never>("24h") // Default selected time range for chart
    private let selectedChartType = CurrentValueSubject<ChartType, Never>(.line) // Default chart type
    private let tableView = UITableView(frame: .zero, style: .plain)      // Main table view

    private var cancellables = Set<AnyCancellable>()                      // Combine cancellables
    private var refreshTimer: Timer?                                      // auto refresh timer
    
    // MARK: - Optimization Properties
    private var isViewVisible = false
    private var lastChartUpdateTime: Date?
    private var isUserInteracting = false
    private var previousChartPointsCount = 0
    
    // MARK: - Rate Limiting & Debouncing Properties
    // Debouncing now handled by Combine operators instead of DispatchWorkItem

    // MARK: - Init
    
    init(coin: Coin) {
        self.coin = coin
        self.viewModel = CoinDetailsVM(coin: coin) // Inject coin into View Model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Cleanup Combine subscriptions
    // Stop timers
    deinit {
        print("🧹 CoinDetailsVC deinit - cleaning up resources for \(coin.symbol)")
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()    // Set up table layout
        bindViewModel()     // Listen for chart data chnages
        bindFilter()        // React to filter selection
        setupScrollDetection() // Detect user scroll interaction
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure proper navigation bar configuration
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        
        // Stop background timers from parent views to prevent unnecessary API calls
        stopParentTimers()
        
        isViewVisible = true
        startSmartAutoRefresh()  // Begin optimized auto-refresh
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewVisible = false
        refreshTimer?.invalidate() // Stops auto-refresh immediately when transition starts
        refreshTimer = nil
        
        // Resume parent timers when leaving coin details
        resumeParentTimers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Only cancel API calls if we're actually leaving (not just a partial swipe)
        if isMovingFromParent || isBeingDismissed {
            viewModel.cancelAllRequests()
            print("🚪 Officially leaving coin details page - cancelled all API calls")
        } else {
            print("🔄 Transition cancelled - staying on coin details page")
        }
    }

    // MARK: - Setup
    
    private func setupTableView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = coin.name
        
        // Ensure normal navigation bar display (no large titles)
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
        // Track user interaction to pause auto-refresh during scrolling
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
    
    // MARK: - Bindings
    
    private func bindViewModel() {
        
        // Chart updates - only update when meaningful changes occur
        viewModel.chartPoints
            .receive(on: DispatchQueue.main) // Switch to main thread for UI updates
            .sink { [weak self] newPoints in //  consume updates
                guard let self = self else { return }
                
                // Skip unnecessary updates
                guard self.shouldUpdateChart(newPoints: newPoints) else { return }
                
                self.updateChartCell(newPoints) // Update UI
                self.previousChartPointsCount = newPoints.count
                self.lastChartUpdateTime = Date()
            }
            .store(in: &cancellables) // Memory Management 
        
        // Enhanced loading state updates using new reactive patterns
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .removeDuplicates() // Avoid unnecessary updates for same loading state
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                // Update loading state without full reload
                if let chartCell = self.getChartCell() {
                    chartCell.updateLoadingState(isLoading)
                }
            }
            .store(in: &cancellables)
        
        // Enhanced error handling with Combine best practices
        viewModel.errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .removeDuplicates() // Prevent duplicate error messages
            .sink { [weak self] errorMessage in
                guard let self = self else { return }
                
                // Only show non-chart errors as alerts (chart errors handled by chartLoadingState)
                let isChartError = errorMessage.contains("chart") || 
                                   errorMessage.contains("data") || 
                                   errorMessage.contains("rate limit") ||
                                   errorMessage.contains("cooldown") ||
                                   errorMessage.contains("network") ||
                                   errorMessage.contains("connection")
                
                if !isChartError {
                    // Show alert for non-chart errors only
                    self.showErrorAlert(message: errorMessage)
                }
                // Chart errors are handled by chartLoadingState subscription below
            }
            .store(in: &cancellables)
        
        // Optional: Use the new combined loading state for more sophisticated UI updates
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
        
        // Stats range updates - reload stats section when range changes
        viewModel.selectedStatsRange
            .receive(on: DispatchQueue.main)
            .removeDuplicates() // Avoid duplicate updates
            .sink { [weak self] _ in
                self?.updateStatsCell()
            }
            .store(in: &cancellables)
        
        // Enhanced OHLC data updates for candlestick charts
        viewModel.ohlcData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newOHLCData in
                guard let self = self else { return }
                
                // Skip unnecessary updates
                guard self.shouldUpdateChart(newPoints: []) else { return }
                
                self.updateChartCellWithOHLC(newOHLCData)
            }
            .store(in: &cancellables)
    }
    
    // Prevents excessive updates on the page
    private func shouldUpdateChart(newPoints: [Double]) -> Bool {
        // Skip if no meaningful change
        if newPoints.isEmpty && previousChartPointsCount == 0 {
            return false
        }
        
        // Skip if same data count and recent update (increased to 3 seconds)
        if newPoints.count == previousChartPointsCount,
           let lastUpdate = lastChartUpdateTime,
           Date().timeIntervalSince(lastUpdate) < 3.0 {
            return false
        }
        
        // Skip if user is actively interacting to prevent disruption
        if isUserInteracting {
            return false
        }
        
        // Skip if data hasn't meaningfully changed (less than 5% difference)
        if !newPoints.isEmpty && previousChartPointsCount > 0 {
            let changePercentage = abs(Double(newPoints.count - previousChartPointsCount)) / Double(previousChartPointsCount)
            if changePercentage < 0.05 {
                return false
            }
        }
        
        return true
    }
    
    private func updateChartCell(_ points: [Double]) {
        guard let chartCell = getChartCell() else {
            // Fallback to section reload if cell not found
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            return
        }
        
        // Direct cell update - much more efficient
        chartCell.updateChartData(points: points, ohlcData: nil, range: selectedRange.value)
        print("📊 Updated chart cell directly with \(points.count) points")
    }
    
    private func updateChartCellWithOHLC(_ ohlcData: [OHLCData]) {
        guard let chartCell = getChartCell() else {
            // Fallback to section reload if cell not found
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            return
        }
        
        // Direct cell update for OHLC data
        chartCell.updateChartData(points: nil, ohlcData: ohlcData, range: selectedRange.value)
        print("📊 Updated chart cell with \(ohlcData.count) OHLC data points")
    }
    
    private func getChartCell() -> ChartCell? {
        let chartIndexPath = IndexPath(row: 0, section: 2)
        
        // Defensive programming: ensure table view is loaded and section exists
        guard chartIndexPath.section < tableView.numberOfSections,
              chartIndexPath.row < tableView.numberOfRows(inSection: chartIndexPath.section) else {
            return nil
        }
        
        return tableView.cellForRow(at: chartIndexPath) as? ChartCell
    }
    
    // MARK: - Landscape Chart
    
    private func presentLandscapeChart() {
        // Get current chart data
        let currentPoints = viewModel.currentChartPoints
        let currentOHLCData = viewModel.currentOHLCData
        let currentRange = selectedRange.value
        let currentChartType = selectedChartType.value
        
        // Create landscape chart controller
        let landscapeVC = LandscapeChartViewController(
            coin: coin,
            selectedRange: currentRange,
            selectedChartType: currentChartType,
            points: currentPoints,
            ohlcData: currentOHLCData,
            viewModel: viewModel
        )
        
        // Set up simplified state synchronization callback
        landscapeVC.onStateChanged = { [weak self] newRange, newChartType in
            guard let self = self else { return }
            
            print("📊 Synchronizing state from landscape: range=\(newRange), chartType=\(newChartType)")
            
            // Simple state update - let Combine handle the UI updates
            self.selectedRange.send(newRange)
            self.selectedChartType.send(newChartType)
        }
        
        // Present modally with smoother transition
        landscapeVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        landscapeVC.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        
        // Use a slight delay and animation to reduce flickering
        present(landscapeVC, animated: true) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("📊 Presented landscape chart for \(self?.coin.name ?? "Unknown") with \(currentPoints.count) points")
            }
        }
    }
    
    // MARK: - Orientation Support
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK: - Landscape State Synchronization
    // State sync is now handled automatically by Combine bindings

    
    private func updateStatsCell() {
        let statsIndexPath = IndexPath(row: 0, section: 3)
        
        // Defensive programming: ensure section exists before accessing
        guard statsIndexPath.section < tableView.numberOfSections else {
            print("⚠️ Stats section doesn't exist yet")
            return
        }
        
        guard let statsCell = tableView.cellForRow(at: statsIndexPath) as? StatsCell else {
            // Fallback to section reload if cell not found
            if statsIndexPath.section < tableView.numberOfSections {
                tableView.reloadSections(IndexSet(integer: 3), with: .none)
            }
            return
        }
        
        // Update stats cell with new data and preserve selected segment
        statsCell.configure(viewModel.currentStats, selectedRange: viewModel.currentSelectedStatsRange) { [weak self] selectedRange in
            print("📊 Selected stats filter: \(selectedRange)")
            self?.viewModel.updateStatsRange(selectedRange)
        }
        
        print("📊 Updated stats cell for range: \(viewModel.currentSelectedStatsRange)")
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func bindFilter() {
        // When user taps a new range (24h, 7d, etc.), debounce and fetch chart data for that range
        selectedRange
            .receive(on: DispatchQueue.main)
            .removeDuplicates() // Prevent duplicate consecutive ranges
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main) // Use Combine's built-in debounce
            .sink { [weak self] range in
                guard let self = self else { return }
                
                print("⚡ Debounced filter change executing: \(range)")
                
                // Keep existing chart completely visible - no loading indicators needed
                // Chart will update seamlessly when new data arrives
                
                // Reset chart state for new range
                self.previousChartPointsCount = 0
                self.lastChartUpdateTime = nil
                
                // Fetch data for new range with high priority (user action)
                self.viewModel.fetchChartData(for: range)
            }
            .store(in: &cancellables)
        
        // Immediate UI feedback for filter changes (before debounce)
        selectedRange
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] range in
                guard let self = self else { return }
                
                print("🔄 Filter changed to: \(range) - keeping existing chart visible")
                
                // NO loading indicators - keep chart completely visible during filter changes
                // The chart will seamlessly update when new data arrives
            }
            .store(in: &cancellables)
        
        // Bind chart type changes
        bindChartType()
    }
    
    private func bindChartType() {
        selectedChartType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chartType in
                guard let self = self else { return }
                
                print("🔄 Chart type changed to: \(chartType)")
                
                // Show loading state immediately when chart type changes (for candlestick)
                if chartType == .candlestick {
                    if let chartCell = self.getChartCell() {
                        chartCell.updateLoadingState(true)
                    }
                }
                
                // Notify ViewModel about chart type change (triggers conditional OHLC fetching)
                print("🔄 Setting chart type \(chartType.rawValue) for range: \(self.selectedRange.value)")
                self.viewModel.setChartType(chartType, for: self.selectedRange.value)
                
                // Update segment cell
                if let segmentCell = self.getSegmentCell() {
                    segmentCell.setChartType(chartType)
                }
                
                // Update chart cell
                if let chartCell = self.getChartCell() {
                    chartCell.switchChartType(to: chartType)
                }
            }
            .store(in: &cancellables)
    }
    
    private func getSegmentCell() -> SegmentCell? {
        let segmentIndexPath = IndexPath(row: 0, section: 1)
        
        // Defensive programming: ensure table view is loaded and section exists
        guard segmentIndexPath.section < tableView.numberOfSections,
              segmentIndexPath.row < tableView.numberOfRows(inSection: segmentIndexPath.section) else {
            return nil
        }
        
        return tableView.cellForRow(at: segmentIndexPath) as? SegmentCell
    }
    
    // MARK: - Smart Auto-Refresh
    
    // Only called when: the view is visible (viewWillAppear)
    // The user is not scrolling ()
    private func startSmartAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        // Conservative refresh interval to respect CoinGecko rate limits
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.performSmartRefresh()
        }
    }
    
    private func performSmartRefresh() {
        // Only refresh if view is visible and user is not interacting
        guard isViewVisible && !isUserInteracting else {
            print("⏸️ Skipping auto-refresh: visible=\(isViewVisible), interacting=\(isUserInteracting)")
            return
        }
        
        print("🔄 Performing smart auto-refresh")
        viewModel.smartAutoRefresh(for: selectedRange.value)
    }
    
    // MARK: - Parent Timer Management
    
    private func stopParentTimers() {
        // Stop CoinListVC auto-refresh timer
        if let parentNav = navigationController,
           let coinListVC = parentNav.viewControllers.first(where: { $0 is CoinListVC }) as? CoinListVC {
            coinListVC.stopAutoRefreshFromChild()
            print("⏸️ Stopped CoinListVC auto-refresh timer")
        }
        
        // Stop WatchlistVC periodic updates (it's embedded in CoinListVC)
        if let parentNav = navigationController,
           let coinListVC = parentNav.viewControllers.first(where: { $0 is CoinListVC }) as? CoinListVC {
            coinListVC.stopWatchlistTimersFromChild()
            print("⏸️ Stopped WatchlistVC periodic updates timer")
        }
        
        // Stop SearchVC timers if navigated from search
        if let parentNav = navigationController,
           let searchVC = parentNav.viewControllers.first(where: { $0 is SearchVC }) as? SearchVC {
            searchVC.stopBackgroundOperationsFromChild()
            print("⏸️ Stopped SearchVC background operations")
        }
    }
    
    private func resumeParentTimers() {
        // Resume CoinListVC auto-refresh timer
        if let parentNav = navigationController,
           let coinListVC = parentNav.viewControllers.first(where: { $0 is CoinListVC }) as? CoinListVC {
            coinListVC.resumeAutoRefreshFromChild()
            print("🔄 Resumed CoinListVC auto-refresh timer")
        }
        
        // Resume WatchlistVC periodic updates (it's embedded in CoinListVC)
        if let parentNav = navigationController,
           let coinListVC = parentNav.viewControllers.first(where: { $0 is CoinListVC }) as? CoinListVC {
            coinListVC.resumeWatchlistTimersFromChild()
            print("🔄 Resumed WatchlistVC periodic updates timer")
        }
        
        // Resume SearchVC background operations if navigated from search
        if let parentNav = navigationController,
           let searchVC = parentNav.viewControllers.first(where: { $0 is SearchVC }) as? SearchVC {
            searchVC.resumeBackgroundOperationsFromChild()
            print("🔄 Resumed SearchVC background operations")
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
            cell.configure(name: coin.name, rank: coin.cmcRank, price: coin.priceString)
            cell.selectionStyle = .none
            return cell
        case 1: // Filter section (Segmented control)
            let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentCell
            cell.configure(items: ["24h", "7d", "30d", "All"], chartType: selectedChartType.value) { [weak self] range in
                self?.selectedRange.send(range)
            }
            
            // Handle chart type toggle
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
            
            cell.onScrollToEdge = { [weak self] dir in
                self?.viewModel.loadMoreHistoricalData(for: self?.selectedRange.value ?? "24h", beforeDate: Date())
            }
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
        case 0: return UITableView.automaticDimension   // Info cell - let it size itself
        case 1: return 60                               // Segment cell
        case 2: return 300                              // Chart cell
        case 3: return UITableView.automaticDimension   // Stats cell
        default: return 44
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 100  // Estimated height for Info cell
        case 1: return 60   // Segment cell
        case 2: return 300  // Chart cell
        case 3: return 200  // Stats cell
        default: return 44
        }
    }
}


