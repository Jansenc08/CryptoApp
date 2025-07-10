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
        startAutoRefresh()  // Begin chart auto-refresh
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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


    
    // MARK: - Bindings
    
    private func bindViewModel() {
        
        // Updates chart section when chart points change
        viewModel.$chartPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                // Only reload the chart section if it’s a fresh fetch
                if self.viewModel.shouldReloadChart {
                    self.tableView.reloadSections(IndexSet(integer: 2), with: .none)
                }

                // Reset flag after chartPoints updates
                self.viewModel.shouldReloadChart = true
            }
            .store(in: &cancellables)
    }

    private func bindFilter() {
        // When user taps a new range (24h, 7d, etc.), fetch chart data for that range
        selectedRange
            .removeDuplicates()
            .sink { [weak self] range in
                self?.viewModel.fetchChartData(for: range)
            }
            .store(in: &cancellables)
    }

    // Auto refresh chart every 60 seconds
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.fetchChartData(for: self.selectedRange.value)
        }
    }
}

// MARK: - TableView Delegate/DataSource

// UITableViewDataSource – Controls what data the table displays
// UITableViewDelegate – Controls how the table looks and behaves

extension CoinDetailsVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 4 } // Info section, filter section, chart section, Statistics Section

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return UITableView.automaticDimension // InfoCell adjusts height based on text
        case 1: return 44                             // SegmentCell height (fixed)
        case 2: return 300                            // ChartCell height (fixed)
        case 3: return UITableView.automaticDimension // StatsCell
        default: return 44
        }
    }

    // Remove extra spacing above and below sections
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
    }
    
    // Provide cells for each section
    // PArt of UITableVieDataSource protocol
    // Responsible for configuring and returning correct cell for a given row in the table
    // Determines which cell to show based on section index
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
            // Set chart scroll edge detection handler
            cell.selectionStyle = .none
            return cell
        case 3: // Stats section
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatsCell", for: indexPath) as! StatsCell
            cell.configure(with: viewModel.currentStats) { selectedRange in
                // TODO: You can use this closure to trigger updates later when needed
                print("Selected stats filter: \(selectedRange)")
            }
            cell.selectionStyle = .none
            return cell

        default:
            return UITableViewCell() //  if an unexpected section is given, returns an empty default cell.
        }
    }
}
