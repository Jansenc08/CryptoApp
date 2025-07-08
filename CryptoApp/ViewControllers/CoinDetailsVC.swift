
import UIKit
import Combine

final class CoinDetailsVC: UIViewController {

    private let coin: Coin
    private let viewModel: CoinDetailsVM
    private let selectedRange = CurrentValueSubject<String, Never>("24h")
    private let chartView = ChartView()
    private let tableView = UITableView(frame: .zero, style: .plain)

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
        setupTableView()
        bindViewModel()
        bindFilter()
        startAutoRefresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
    }

    private func setupTableView() {
        view.backgroundColor = .systemBackground
        navigationItem.title = coin.name

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never

        tableView.register(InfoCell.self, forCellReuseIdentifier: "InfoCell")
        tableView.register(SegmentCell.self, forCellReuseIdentifier: "SegmentCell")
        tableView.register(ChartCell.self, forCellReuseIdentifier: "ChartCell")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$chartPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                self?.chartView.update(with: points, range: self?.selectedRange.value ?? "24h")
            }
            .store(in: &cancellables)
    }

    private func bindFilter() {
        selectedRange
            .removeDuplicates()
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
}

extension CoinDetailsVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 3 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return UITableView.automaticDimension
        case 1: return 44
        case 2: return 300
        default: return 44
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "InfoCell", for: indexPath) as! InfoCell
            cell.configure(name: coin.name, rank: coin.cmcRank, price: coin.priceString)
            cell.selectionStyle = .none
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentCell
            cell.configure(items: ["24h", "7d", "30d", "All"]) { [weak self] range in
                self?.selectedRange.send(range)
            }
            cell.selectionStyle = .none
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChartCell", for: indexPath) as! ChartCell
            cell.embed(chartView)
            chartView.onScrollToEdge = { [weak self] dir in
                self?.viewModel.loadMoreHistoricalData(for: self?.selectedRange.value ?? "24h", beforeDate: Date())
            }
            cell.selectionStyle = .none
            return cell
        default:
            return UITableViewCell()
        }
    }
}
