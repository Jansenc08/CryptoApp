import UIKit
import Combine

final class CoinDetailsVC: UIViewController {
    
    // MARK: - Properties

    private let coin: Coin
    private let viewModel: CoinDetailsVM
    private let selectedRange = CurrentValueSubject<String, Never>("24h") // Default selected time range for chart
    private let tableView = UITableView(frame: .zero, style: .plain) // Main table view

    private var cancellables = Set<AnyCancellable>() // Combine cancellables
    private var refreshTimer: Timer? //  auto refresh timer
    
    // MARK: - Optimization Properties
    private var isViewVisible = false
    private var lastChartUpdateTime: Date?
    private var isUserInteracting = false
    private var previousChartPointsCount = 0

    // MARK: - Init
    
    init(coin: Coin) {
        self.coin = coin
        self.viewModel = CoinDetailsVM(coin: coin) // Inject coin into View Model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        isViewVisible = true
        startSmartAutoRefresh()  // Begin optimized auto-refresh
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewVisible = false
        refreshTimer?.invalidate() // Stops auto-refresh when we leave the page
    }

    // MARK: - Setup
    
    private func setupTableView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = coin.name
        
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
        viewModel.$chartPoints
            .receive(on: DispatchQueue.main) // Switch to main thread for UI updates
            .sink { [weak self] newPoints in //  consume updates
                guard let self = self else { return }
                
                // Skip unnecessary updates
                guard self.shouldUpdateChart(newPoints: newPoints) else { return }
                
                self.updateChartCell(with: newPoints) // Update UI
                self.previousChartPointsCount = newPoints.count
                self.lastChartUpdateTime = Date()
            }
            .store(in: &cancellables) // Memory Management 
        
        // Loading state updates
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                // Update loading state without full reload
                if let chartCell = self.getChartCell() {
                    chartCell.setLoading(isLoading)
                }
            }
            .store(in: &cancellables)
        
        // Error handling
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] errorMessage in
                self?.showErrorAlert(message: errorMessage)
            }
            .store(in: &cancellables)
    }
    
    // Prevents excessive updates on the page
    private func shouldUpdateChart(newPoints: [Double]) -> Bool {
        // Skip if no meaningful change
        if newPoints.isEmpty && previousChartPointsCount == 0 {
            return false
        }
        
        // Skip if same data count and recent update
        if newPoints.count == previousChartPointsCount,
           let lastUpdate = lastChartUpdateTime,
           Date().timeIntervalSince(lastUpdate) < 1.0 {
            return false
        }
        
        // Skip if user is actively interacting to prevent disruption
        if isUserInteracting {
            return false
        }
        
        return true
    }
    
    private func updateChartCell(with points: [Double]) {
        guard let chartCell = getChartCell() else {
            // Fallback to section reload if cell not found
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            return
        }
        
        // Direct cell update - much more efficient
        chartCell.updateChartData(points: points, range: selectedRange.value)
        print("📊 Updated chart cell directly with \(points.count) points")
    }
    
    private func getChartCell() -> ChartCell? {
        let chartIndexPath = IndexPath(row: 0, section: 2)
        return tableView.cellForRow(at: chartIndexPath) as? ChartCell
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func bindFilter() {
        // When user taps a new range (24h, 7d, etc.), fetch chart data for that range
        selectedRange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] range in
                guard let self = self else { return }
                
                print("🔄 Filter changed to: \(range)")
                
                // Reset chart state for new range
                self.previousChartPointsCount = 0
                self.lastChartUpdateTime = nil
                
                // Fetch data for new range
                self.viewModel.fetchChartData(for: range)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Smart Auto-Refresh
    
    // Only called when: the view is visible (viewWillAppear)
    // The user is not scrolling ()
    private func startSmartAutoRefresh() {
        refreshTimer?.invalidate()
        
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
        viewModel.fetchChartData(for: selectedRange.value)
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
            cell.configure(items: ["24h", "7d", "30d", "All"]) { [weak self] range in
                self?.selectedRange.send(range)
            }
            cell.selectionStyle = .none
            return cell
        case 2: // Chart section
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChartCell", for: indexPath) as! ChartCell
            cell.configure(points: viewModel.chartPoints, range: selectedRange.value)
            cell.onScrollToEdge = { [weak self] dir in
                self?.viewModel.loadMoreHistoricalData(for: self?.selectedRange.value ?? "24h", beforeDate: Date())
            }
            cell.selectionStyle = .none
            return cell
        case 3: // Stats section
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatsCell", for: indexPath) as! StatsCell
            cell.configure(with: viewModel.currentStats) { selectedRange in
                print("Selected stats filter: \(selectedRange)")
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

// MARK: - ChartCell Extension Support

extension ChartCell {
    func updateChartData(points: [Double], range: String) {
        // Update chart data without full cell recreation
        configure(points: points, range: range)
    }
    
    func setLoading(_ isLoading: Bool) {
        // Show/hide loading indicator
    }
}
