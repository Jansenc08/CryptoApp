//
//  LandscapeChartViewController.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import UIKit
import Combine

final class LandscapeChartVC: UIViewController {
    
    // MARK: - Properties
    
    private let coin: Coin
    private var selectedRange: String = "24h"
    private var selectedChartType: ChartType = .line
    private var cancellables = Set<AnyCancellable>()
        private let viewModel: CoinDetailsVM
    
    // State synchronization callback - only filter and chart type
    var onStateChanged: ((String, ChartType) -> Void)?
    
    // Chart data
    private var currentPoints: [Double] = []
    private var currentOHLCData: [OHLCData] = []
    
    // UI Components
    private let navigationBar = UINavigationBar()
    private let containerView = UIView()
    private let lineChartView = ChartView()
    private let candlestickChartView = CandlestickChartView()
    private let controlsContainer = UIView()
    private let rangeSegmentView = SegmentView()
    private let chartTypeToggle = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    
    // MARK: - Init
    
    init(coin: Coin, selectedRange: String, selectedChartType: ChartType, points: [Double], ohlcData: [OHLCData], viewModel: CoinDetailsVM) {
        self.coin = coin
        self.selectedRange = selectedRange
        self.selectedChartType = selectedChartType
        self.currentPoints = points
        self.currentOHLCData = ohlcData
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cancellables.removeAll()
        onStateChanged = nil // Clean up closure to prevent memory leaks
        print("📱 LandscapeChartViewController deinit - cleaned up state callback")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCharts()
        setupControls()
        bindViewModel()
        showChart(type: selectedChartType, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Prepare UI without forcing orientation yet
        showChart(type: selectedChartType, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Force landscape orientation after the view has stabilized to reduce flickering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if #available(iOS 16.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                }
            } else {
                // Fallback for older iOS versions
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
            UIView.performWithoutAnimation {
                self?.view.setNeedsLayout()
                self?.view.layoutIfNeeded()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Sync final state back to portrait mode
        onStateChanged?(selectedRange, selectedChartType)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Ensure orientation is reset after view has disappeared
        resetOrientationToPortrait()
    }
    
    private func resetOrientationToPortrait() {
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { result in
                        print("📱 iOS 16+ orientation reset result: \(result)")
                    }
                }
            } else {
                // Fallback for older iOS versions
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
            
            // Force navigation controller to re-evaluate supported orientations
            if let navController = self.presentingViewController as? UINavigationController {
                navController.setNeedsUpdateOfSupportedInterfaceOrientations()
            } else {
                self.presentingViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            
            print("📱 Reset orientation to portrait")
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Navigation Bar
        setupNavigationBar()
        
        // Container for charts
        containerView.backgroundColor = .clear
        view.addSubview(containerView)
        
        // Controls at bottom
        controlsContainer.backgroundColor = .secondarySystemBackground
        controlsContainer.layer.cornerRadius = 16
        controlsContainer.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(controlsContainer)
        
        // Layout
        setupConstraints()
    }
    
    private func setupNavigationBar() {
        navigationBar.isTranslucent = true
        navigationBar.backgroundColor = .clear
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.shadowImage = UIImage()
        
        let navItem = UINavigationItem(title: "\(coin.name) Chart")
        navItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        
        // Close button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .systemGray2
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        navigationBar.setItems([navItem], animated: false)
        view.addSubview(navigationBar)
    }
    
    private func setupConstraints() {
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Navigation bar at top
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Controls at bottom
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Chart container fills the middle
            containerView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 10),
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            containerView.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: -10)
        ])
    }
    
    // MARK: - Chart Setup
    
    private func setupCharts() {
        // Add both chart views to container
        containerView.addSubview(lineChartView)
        containerView.addSubview(candlestickChartView)
        
        lineChartView.translatesAutoresizingMaskIntoConstraints = false
        candlestickChartView.translatesAutoresizingMaskIntoConstraints = false
        
        // Both charts fill the container
        NSLayoutConstraint.activate([
            lineChartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            lineChartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            lineChartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lineChartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            candlestickChartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            candlestickChartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            candlestickChartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            candlestickChartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // Load initial data
        lineChartView.update(currentPoints, range: selectedRange)
        candlestickChartView.update(currentOHLCData, range: selectedRange)
    }
    
    // MARK: - Controls Setup
    
    private func setupControls() {
        // Range segment control
        rangeSegmentView.configure(withItems: ["24h", "7d", "30d", "All"])
        if let selectedIndex = ["24h", "7d", "30d", "All"].firstIndex(of: selectedRange) {
            rangeSegmentView.setSelectedIndex(selectedIndex)
        }
        
        rangeSegmentView.onSelectionChanged = { [weak self] index in
            guard let self = self else { return }
            let ranges = ["24h", "7d", "30d", "All"]
            self.selectedRange = ranges[index]
            
            // FIXED: Don't fetch data directly - let parent handle state synchronization
            print("📊 Landscape chart range changed to: \(self.selectedRange)")
            
            // Only notify parent about filter change - parent will handle data fetching
            self.onStateChanged?(self.selectedRange, self.selectedChartType)
        }
        
        // Chart type toggle
        setupChartTypeToggle()
        
        // Layout controls
        controlsContainer.addSubview(rangeSegmentView)
        controlsContainer.addSubview(chartTypeToggle)
        
        rangeSegmentView.translatesAutoresizingMaskIntoConstraints = false
        chartTypeToggle.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            rangeSegmentView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 20),
            rangeSegmentView.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            rangeSegmentView.trailingAnchor.constraint(equalTo: chartTypeToggle.leadingAnchor, constant: -20),
            
            chartTypeToggle.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -20),
            chartTypeToggle.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            chartTypeToggle.widthAnchor.constraint(equalToConstant: 50),
            chartTypeToggle.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupChartTypeToggle() {
        chartTypeToggle.backgroundColor = .systemBlue.withAlphaComponent(0.15)
        chartTypeToggle.layer.cornerRadius = 12
        chartTypeToggle.layer.masksToBounds = true
        
        updateChartTypeToggleAppearance()
        
        chartTypeToggle.addTarget(self, action: #selector(chartTypeToggleTapped), for: .touchUpInside)
    }
    
    private func updateChartTypeToggleAppearance() {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = UIImage(systemName: selectedChartType.systemImageName, withConfiguration: config)
        
        let (tintColor, backgroundColor): (UIColor, UIColor)
        switch selectedChartType {
        case .line:
            tintColor = UIColor.systemBlue
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        case .candlestick:
            tintColor = UIColor.systemOrange
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        }
        
        chartTypeToggle.setImage(image, for: .normal)
        chartTypeToggle.backgroundColor = backgroundColor
        chartTypeToggle.tintColor = tintColor
    }
    
    // MARK: - ViewModel Binding
    
    private func bindViewModel() {
        // Bind chart points updates
        viewModel.chartPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                guard let self = self else { return }
                self.currentPoints = points
                self.lineChartView.update(points, range: self.selectedRange)
                print("📊 Landscape: Updated line chart with \(points.count) points")
            }
            .store(in: &cancellables)
        
        // Bind OHLC data updates
        viewModel.ohlcData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ohlcData in
                guard let self = self else { return }
                self.currentOHLCData = ohlcData
                self.candlestickChartView.update(ohlcData, range: self.selectedRange)
                print("📊 Landscape: Updated candlestick chart with \(ohlcData.count) OHLC entries")
            }
            .store(in: &cancellables)
        
        // Bind loading state
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                if isLoading {
                    // Show loading indicator
                    _ = SkeletonLoadingManager.showChartSkeleton(in: self.containerView)
                    self.lineChartView.alpha = 0.6
                    self.candlestickChartView.alpha = 0.6
                } else {
                    // Hide loading indicator
                    SkeletonLoadingManager.dismissChartSkeleton(from: self.containerView)
                    self.lineChartView.alpha = 1.0
                    self.candlestickChartView.alpha = 1.0
                }
            }
            .store(in: &cancellables)
        
        // Bind error messages
        viewModel.errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showErrorAlert(message: error)
            }
            .store(in: &cancellables)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    

    
    // MARK: - Chart Display
    
    private func showChart(type: ChartType, animated: Bool = true) {
        selectedChartType = type
        updateChartTypeToggleAppearance()
        
        let showLineChart = (type == .line)
        
        if animated {
            UIView.transition(with: containerView, duration: 0.3, options: .transitionCrossDissolve) {
                self.lineChartView.isHidden = !showLineChart
                self.candlestickChartView.isHidden = showLineChart
            }
        } else {
            lineChartView.isHidden = !showLineChart
            candlestickChartView.isHidden = showLineChart
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Immediately dismiss and handle orientation in the completion
        dismiss(animated: true) { [weak self] in
            // Reset orientation after dismissal completes
            self?.resetOrientationToPortrait()
            print("📊 Dismissed landscape chart")
        }
    }
    
    @objc private func chartTypeToggleTapped() {
        // Toggle chart type
        selectedChartType = selectedChartType == .line ? .candlestick : .line
        showChart(type: selectedChartType, animated: true)
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Notify parent about chart type change
        onStateChanged?(selectedRange, selectedChartType)
    }
} 
