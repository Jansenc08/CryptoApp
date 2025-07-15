//
//  FilterModalVC.swift
//  CryptoApp
//
//  Created by AI Assistant on 7/7/25.
//

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
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var handleView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray3
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .systemGray
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
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
        
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupFilterOptions()
        animateIn()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        titleLabel.text = filterType.title
        
        view.addSubview(containerView)
        containerView.addSubview(handleView)
        containerView.addSubview(closeButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            // Container view
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 400),
            
            // Handle view
            handleView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            handleView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 40),
            handleView.heightAnchor.constraint(equalToConstant: 4),
            
            // Close button
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -16),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            
            // Table view
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupGestures() {
        // Tap to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Pan to dismiss
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(panGesture)
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
    
    // MARK: - Animations
    
    private func animateIn() {
        containerView.transform = CGAffineTransform(translationX: 0, y: containerView.frame.height)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.containerView.transform = .identity
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.containerView.frame.height)
            self.view.alpha = 0
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(cancelled: true)
    }
    
    @objc private func backgroundTapped() {
        dismiss(cancelled: true)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                containerView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            }
        case .ended:
            let shouldDismiss = translation.y > 100 || velocity.y > 1000
            
            if shouldDismiss {
                dismiss(cancelled: true)
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.containerView.transform = .identity
                }
            }
        default:
            break
        }
    }
    
    private func dismiss(cancelled: Bool) {
        animateOut { [weak self] in
            guard let self = self else { return }
            if cancelled && !self.wasSelectionMade {
                self.delegate?.filterModalVCDidCancel(self)
            }
            self.dismiss(animated: false)
        }
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

// MARK: - UIGestureRecognizerDelegate

extension FilterModalVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == view
    }
} 