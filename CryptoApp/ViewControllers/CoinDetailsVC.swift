import UIKit
import Combine
import DGCharts

final class CoinDetailsVC: UIViewController {

    private let coin: Coin
    private let viewModel: CoinDetailsVM
    private let selectedRange = CurrentValueSubject<String, Never>("24h")
    private let nameLabel = UILabel()
    private let rankLabel = UILabel()
    private let priceLabel = UILabel()
    private let segmentedFilter = SegmentView()
    private let chartView = ChartView()

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init(coin: Coin) {
        self.coin = coin
        self.viewModel = CoinDetailsVM(coin: coin)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        bindViewModel()
        bindFilter()
        startAutoRefresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground
        navigationItem.title = coin.name

        nameLabel.text = coin.name
        nameLabel.font = .boldSystemFont(ofSize: 24)

        rankLabel.text = "#\(coin.cmcRank)"
        rankLabel.font = .systemFont(ofSize: 16)
        rankLabel.textColor = .secondaryLabel

        priceLabel.text = coin.priceString
        priceLabel.font = .systemFont(ofSize: 20, weight: .medium)
        priceLabel.textColor = .label

        segmentedFilter.configure(withItems: ["24h", "7d", "30d", "All"])
        segmentedFilter.onSelectionChanged = { [weak self] index in
            let range = ["24h", "7d", "30d", "365d"][index]
            self?.selectedRange.send(range)
        }

        let topStack = UIStackView(arrangedSubviews: [nameLabel, rankLabel])
        topStack.axis = .horizontal
        topStack.spacing = 10
        topStack.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topStack, priceLabel, segmentedFilter, chartView])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            chartView.heightAnchor.constraint(equalToConstant: 280),
        ])

        // Setup chart scroll callbacks
        chartView.onScrollToEdge = { [weak self] direction in
            self?.handleEdgeScroll(direction)
        }
    }

    private func bindViewModel() {
        viewModel.$chartPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                self?.updateChart(with: points)
            }
            .store(in: &cancellables)
    }

    private func bindFilter() {
        selectedRange
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] range in
                self?.viewModel.fetchChartData(for: range)
            }
            .store(in: &cancellables)
    }



    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.fetchChartData(for: self.selectedRange.value)
        }
    }

    private func updateChart(with dataPoints: [Double]) {
        chartView.update(with: dataPoints, range: selectedRange.value)
    }

    private func handleEdgeScroll(_ direction: ChartView.ScrollDirection) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        switch direction {
        case .left:
            // Load more historical data
            viewModel.loadMoreHistoricalData(for: selectedRange.value, beforeDate: Date())
        case .right:
            // Could implement real-time data loading here
            break
        }
    }
}
