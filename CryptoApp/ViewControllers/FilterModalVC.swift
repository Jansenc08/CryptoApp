import UIKit

// MARK: - FilterModalVC Delegate

protocol FilterModalVCDelegate: AnyObject {
    func filterModalVC(_ modalVC: FilterModalVC, didSelectPriceChangeFilter filter: PriceChangeFilter)
    func filterModalVC(_ modalVC: FilterModalVC, didSelectTopCoinsFilter filter: TopCoinsFilter)
    func filterModalVCDidCancel(_ modalVC: FilterModalVC)
}

// MARK: - FilterModalVC

class FilterModalVC: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: FilterModalVCDelegate?
    private let filterType: FilterType
    private let currentState: FilterState
    private var filterOptions: [FilterOption] = []
    private var wasSelectionMade = false  // Track if a selection was made
    
    // MARK: - UI Components
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FilterCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // MARK: - Init
    
    init(filterType: FilterType, currentState: FilterState) {
        self.filterType = filterType
        self.currentState = currentState
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFilterOptions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        titleLabel.text = filterType.title
        
        // Add close button to navigation bar to match AddCoinsVC
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemGray
        
        view.addSubviews(titleLabel, tableView)
        
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Table view
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupFilterOptions() {
        switch filterType {
        case .priceChange:
            filterOptions = PriceChangeFilter.allCases.map { filter in
                PriceChangeFilterOption(
                    filter: filter,
                    isSelected: filter == currentState.priceChangeFilter
                )
            }
        case .topCoins:
            filterOptions = TopCoinsFilter.allCases.map { filter in
                TopCoinsFilterOption(
                    filter: filter,
                    isSelected: filter == currentState.topCoinsFilter
                )
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(cancelled: true)
    }
    
    private func dismiss(cancelled: Bool) {
        if cancelled && !wasSelectionMade {
            delegate?.filterModalVCDidCancel(self)
        }
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource

extension FilterModalVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filterOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FilterCell", for: indexPath)
        let option = filterOptions[indexPath.row]
        
        cell.textLabel?.text = option.displayName
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cell.accessoryType = option.isSelected ? .checkmark : .none
        cell.tintColor = UIColor.systemBlue
        cell.backgroundColor = UIColor.clear
        cell.selectionStyle = .default
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FilterModalVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedOption = filterOptions[indexPath.row]
        
        // Mark that a selection was made
        wasSelectionMade = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            switch self.filterType {
            case .priceChange:
                if let priceChangeOption = selectedOption as? PriceChangeFilterOption {
                    self.delegate?.filterModalVC(self, didSelectPriceChangeFilter: priceChangeOption.filter)
                }
            case .topCoins:
                if let topCoinsOption = selectedOption as? TopCoinsFilterOption {
                    self.delegate?.filterModalVC(self, didSelectTopCoinsFilter: topCoinsOption.filter)
                }
            }
            
            self.dismiss(cancelled: false)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}