import UIKit
import Combine

protocol ChartSettingsDelegate: AnyObject {
    func chartSettingsDidUpdate()
    func smoothingSettingsChanged(enabled: Bool, type: ChartSmoothingHelper.SmoothingType)
}

final class ChartSettingsVC: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: ChartSettingsDelegate?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Smoothing Section
    private let smoothingSectionLabel = UILabel()
    private let smoothingEnabledSwitch = UISwitch()
    private let smoothingAlgorithmButton = UIButton(type: .system)
    
    // Visual Section
    private let visualSectionLabel = UILabel()
    private let gridLinesSwitch = UISwitch()
    private let priceLabelsSwitch = UISwitch()
    private let autoScaleSwitch = UISwitch()
    
    // Appearance Section
    private let appearanceSectionLabel = UILabel()
    private let colorThemeSegmentedControl = UISegmentedControl(items: ["Classic", "Ocean", "Mono", "Accessibility"])
    private let lineThicknessSegmentedControl = UISegmentedControl(items: ["Thin", "Normal", "Thick", "Bold"])
    
    // Animation Section
    private let animationSectionLabel = UILabel()
    private let animationSpeedSegmentedControl = UISegmentedControl(items: ["Instant", "Fast", "Normal", "Smooth"])
    
    // Presets Section
    private let presetsSectionLabel = UILabel()
    private let tradingPresetButton = UIButton(type: .system)
    private let simplePresetButton = UIButton(type: .system)
    private let analysisPresetButton = UIButton(type: .system)
    
    // Current settings
    private var currentSmoothingEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "ChartSmoothingEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "ChartSmoothingEnabled") // Default enabled
        }
        return UserDefaults.standard.bool(forKey: "ChartSmoothingEnabled")
    }()
    private var currentSmoothingType: ChartSmoothingHelper.SmoothingType = {
        let savedType = UserDefaults.standard.string(forKey: "ChartSmoothingType") ?? "adaptive"
        return ChartSmoothingHelper.SmoothingType(rawValue: savedType) ?? .adaptive
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCurrentSettings()
        setupActions()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure title and subtitle
        titleLabel.text = "Chart Settings"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        
        subtitleLabel.text = "Let us know your preferences below"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .secondaryLabel
        
        // Configure section labels
        setupSectionLabel(smoothingSectionLabel, text: "Smoothing")
        setupSectionLabel(visualSectionLabel, text: "Display")
        setupSectionLabel(appearanceSectionLabel, text: "Appearance")
        setupSectionLabel(animationSectionLabel, text: "Animation")
        setupSectionLabel(presetsSectionLabel, text: "Quick Presets")
        
        // Configure switches
        setupSwitch(smoothingEnabledSwitch)
        setupSwitch(gridLinesSwitch)
        setupSwitch(priceLabelsSwitch)
        setupSwitch(autoScaleSwitch)
        
        // Configure segmented controls
        setupSegmentedControl(colorThemeSegmentedControl)
        setupSegmentedControl(lineThicknessSegmentedControl)
        setupSegmentedControl(animationSpeedSegmentedControl)
        
        // Configure buttons
        setupButton(smoothingAlgorithmButton, title: "Algorithm: Adaptive")
        setupPresetButton(tradingPresetButton, title: "Trading View", subtitle: "Professional analysis")
        setupPresetButton(simplePresetButton, title: "Simple View", subtitle: "Clean and minimal")
        setupPresetButton(analysisPresetButton, title: "Analysis View", subtitle: "Raw data focus")
        
        setupConstraints()
    }
    
    private func setupSectionLabel(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
    }
    
    private func setupSwitch(_ switchControl: UISwitch) {
        switchControl.onTintColor = .systemBlue
    }
    
    private func setupSegmentedControl(_ control: UISegmentedControl) {
        control.selectedSegmentTintColor = .systemBlue
        control.backgroundColor = .secondarySystemBackground
        
        // Set text colors for better contrast
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.label
        ], for: .normal)
        
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.white
        ], for: .selected)
    }
    
    private func setupButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    }
    
    private func setupPresetButton(_ button: UIButton, title: String, subtitle: String) {
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 12
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        // Create attributed title
        let attributedTitle = NSMutableAttributedString()
        attributedTitle.append(NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.label
        ]))
        attributedTitle.append(NSAttributedString(string: "\n" + subtitle, attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? .white : .darkGray
            }
        ]))
        
        button.setAttributedTitle(attributedTitle, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Add all UI elements to content view
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            createSpacing(24),
            
            // Smoothing Section
            smoothingSectionLabel,
            createSettingRow(label: "Enable Smoothing", control: smoothingEnabledSwitch),
            smoothingAlgorithmButton,
            createSpacing(24),
            
            // Visual Section
            visualSectionLabel,
            createSettingRow(label: "Grid Lines", control: gridLinesSwitch),
            createSettingRow(label: "Price Labels", control: priceLabelsSwitch),
            createSettingRow(label: "Auto Scale Y-Axis", control: autoScaleSwitch),
            createSpacing(24),
            
            // Appearance Section
            appearanceSectionLabel,
            createLabeledControl(label: "Color Theme", control: colorThemeSegmentedControl),
            createLabeledControl(label: "Line Thickness", control: lineThicknessSegmentedControl),
            createSpacing(24),
            
            // Animation Section
            animationSectionLabel,
            createLabeledControl(label: "Speed", control: animationSpeedSegmentedControl),
            createSpacing(24),
            
            // Presets Section
            presetsSectionLabel,
            tradingPresetButton,
            simplePresetButton,
            analysisPresetButton,
            createSpacing(40)
        ])
        
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createSpacing(_ height: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }
    
    private func createSettingRow(label: String, control: UIControl) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        
        container.addSubview(titleLabel)
        container.addSubview(control)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 56),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func createLabeledControl(label: String, control: UIControl) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .secondaryLabel  // Gray color for subtler appearance
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, control])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Settings Management
    
    private func loadCurrentSettings() {
        // Use smoothing settings from configure() method (already set from view model)
        smoothingEnabledSwitch.isOn = currentSmoothingEnabled
        smoothingAlgorithmButton.isEnabled = currentSmoothingEnabled
        updateSmoothingAlgorithmButton()
        
        // Load visual settings
        gridLinesSwitch.isOn = UserDefaults.standard.bool(forKey: "ChartGridLinesEnabled")
        priceLabelsSwitch.isOn = UserDefaults.standard.bool(forKey: "ChartPriceLabelsEnabled")
        
        // Auto Scale: Default OFF for better candlestick visibility
        // When enabled, makes candlesticks nearly invisible when zoomed out
        if UserDefaults.standard.object(forKey: "ChartAutoScaleEnabled") == nil {
            UserDefaults.standard.set(false, forKey: "ChartAutoScaleEnabled") // Explicit default
        }
        autoScaleSwitch.isOn = UserDefaults.standard.bool(forKey: "ChartAutoScaleEnabled")
        
        // Load appearance settings
        let themeRawValue = UserDefaults.standard.string(forKey: "ChartColorTheme") ?? "classic"
        if let theme = ChartColorTheme(rawValue: themeRawValue) {
            switch theme {
            case .classic: colorThemeSegmentedControl.selectedSegmentIndex = 0
            case .ocean: colorThemeSegmentedControl.selectedSegmentIndex = 1
            case .monochrome: colorThemeSegmentedControl.selectedSegmentIndex = 2
            case .accessibility: colorThemeSegmentedControl.selectedSegmentIndex = 3
            }
        }
        
        let thickness = UserDefaults.standard.double(forKey: "ChartLineThickness")
        switch thickness {
        case 1.5: lineThicknessSegmentedControl.selectedSegmentIndex = 0
        case 2.5: lineThicknessSegmentedControl.selectedSegmentIndex = 1
        case 3.5: lineThicknessSegmentedControl.selectedSegmentIndex = 2
        case 4.5: lineThicknessSegmentedControl.selectedSegmentIndex = 3
        default: lineThicknessSegmentedControl.selectedSegmentIndex = 1
        }
        
        // Load animation settings
        let speed = UserDefaults.standard.double(forKey: "ChartAnimationSpeed")
        switch speed {
        case 0.0: animationSpeedSegmentedControl.selectedSegmentIndex = 0
        case 0.3: animationSpeedSegmentedControl.selectedSegmentIndex = 1
        case 0.6: animationSpeedSegmentedControl.selectedSegmentIndex = 2
        case 1.0: animationSpeedSegmentedControl.selectedSegmentIndex = 3
        default: animationSpeedSegmentedControl.selectedSegmentIndex = 2
        }
    }
    
    private func updateSmoothingAlgorithmButton() {
        let algorithmName = getAlgorithmDisplayName(currentSmoothingType)
        smoothingAlgorithmButton.setTitle("Algorithm: \(algorithmName)", for: .normal)
        smoothingAlgorithmButton.alpha = currentSmoothingEnabled ? 1.0 : 0.5
    }
    
    private func getAlgorithmDisplayName(_ type: ChartSmoothingHelper.SmoothingType) -> String {
        switch type {
        case .adaptive: return "Adaptive"
        case .basic: return "Basic"
        case .gaussian: return "Gaussian"
        case .savitzkyGolay: return "Savitzky-Golay"
        case .median: return "Median"
        case .loess: return "LOESS"
        case .bollinger: return "Bollinger"
        }
    }
    
    // MARK: - Actions
    
    private func setupActions() {
        smoothingEnabledSwitch.addTarget(self, action: #selector(smoothingEnabledChanged), for: .valueChanged)
        smoothingAlgorithmButton.addTarget(self, action: #selector(smoothingAlgorithmTapped), for: .touchUpInside)
        
        gridLinesSwitch.addTarget(self, action: #selector(gridLinesChanged), for: .valueChanged)
        priceLabelsSwitch.addTarget(self, action: #selector(priceLabelsChanged), for: .valueChanged)
        autoScaleSwitch.addTarget(self, action: #selector(autoScaleChanged), for: .valueChanged)
        
        colorThemeSegmentedControl.addTarget(self, action: #selector(colorThemeChanged), for: .valueChanged)
        lineThicknessSegmentedControl.addTarget(self, action: #selector(lineThicknessChanged), for: .valueChanged)
        animationSpeedSegmentedControl.addTarget(self, action: #selector(animationSpeedChanged), for: .valueChanged)
        
        tradingPresetButton.addTarget(self, action: #selector(tradingPresetTapped), for: .touchUpInside)
        simplePresetButton.addTarget(self, action: #selector(simplePresetTapped), for: .touchUpInside)
        analysisPresetButton.addTarget(self, action: #selector(analysisPresetTapped), for: .touchUpInside)
    }
    
    @objc private func smoothingEnabledChanged() {
        currentSmoothingEnabled = smoothingEnabledSwitch.isOn
        updateSmoothingAlgorithmButton()
        delegate?.smoothingSettingsChanged(enabled: currentSmoothingEnabled, type: currentSmoothingType)
        delegate?.chartSettingsDidUpdate()
    }
    
    @objc private func smoothingAlgorithmTapped() {
        guard currentSmoothingEnabled else { return }
        presentSmoothingAlgorithmPicker()
    }
    
    @objc private func gridLinesChanged() {
        UserDefaults.standard.set(gridLinesSwitch.isOn, forKey: "ChartGridLinesEnabled")
        delegate?.chartSettingsDidUpdate()
    }
    
    @objc private func priceLabelsChanged() {
        UserDefaults.standard.set(priceLabelsSwitch.isOn, forKey: "ChartPriceLabelsEnabled")
        delegate?.chartSettingsDidUpdate()
    }
    
    @objc private func autoScaleChanged() {
        UserDefaults.standard.set(autoScaleSwitch.isOn, forKey: "ChartAutoScaleEnabled")
        
        // Show helpful explanation when Auto Scale is enabled
        if autoScaleSwitch.isOn {
            let alert = UIAlertController(
                title: "Auto Scale Y-Axis",
                message: "Auto Scale adjusts the price range to fit visible data.\n\n⚠️ Note: This may make candlesticks appear very small when viewing long time periods (30d, All) because the price range becomes very large.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Got it", style: .default))
            present(alert, animated: true)
        }
        
        delegate?.chartSettingsDidUpdate()
    }
    
    @objc private func colorThemeChanged() {
        let themes: [ChartColorTheme] = [.classic, .ocean, .monochrome, .accessibility]
        let selectedTheme = themes[colorThemeSegmentedControl.selectedSegmentIndex]
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "ChartColorTheme")
        delegate?.chartSettingsDidUpdate()
    }
    
    @objc private func lineThicknessChanged() {
        let thicknesses: [Double] = [1.5, 2.5, 3.5, 4.5]
        let selectedThickness = thicknesses[lineThicknessSegmentedControl.selectedSegmentIndex]
        UserDefaults.standard.set(selectedThickness, forKey: "ChartLineThickness")
        delegate?.chartSettingsDidUpdate()
    }
    
    @objc private func animationSpeedChanged() {
        let speeds: [Double] = [0.0, 0.3, 0.6, 1.0]
        let selectedSpeed = speeds[animationSpeedSegmentedControl.selectedSegmentIndex]
        UserDefaults.standard.set(selectedSpeed, forKey: "ChartAnimationSpeed")
        delegate?.chartSettingsDidUpdate()
    }
    
    @objc private func tradingPresetTapped() {
        applyTradingPreset()
    }
    
    @objc private func simplePresetTapped() {
        applySimplePreset()
    }
    
    @objc private func analysisPresetTapped() {
        applyAnalysisPreset()
    }
    
    // MARK: - Smoothing Algorithm Picker
    
    private func presentSmoothingAlgorithmPicker() {
        let alert = UIAlertController(title: "Smoothing Algorithm", message: "Choose how chart data is smoothed", preferredStyle: .actionSheet)
        
        let algorithms: [(ChartSmoothingHelper.SmoothingType, String, String)] = [
            (.adaptive, "Adaptive", "Smart smoothing based on volatility"),
            (.basic, "Basic", "Simple moving average"),
            (.gaussian, "Gaussian", "Very smooth, removes noise"),
            (.savitzkyGolay, "Savitzky-Golay", "Preserves peaks - great for crypto"),
            (.median, "Median", "Removes price spikes"),
            (.loess, "LOESS", "Follows trends closely"),
            (.bollinger, "Bollinger", "Crypto-specific smoothing")
        ]
        
        for (type, title, _) in algorithms {
            let isSelected = currentSmoothingType == type
            let actionTitle = "\(title) \(isSelected ? "✓" : "")"
            
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                self?.currentSmoothingType = type
                self?.updateSmoothingAlgorithmButton()
                if let self = self {
                    self.delegate?.smoothingSettingsChanged(enabled: self.currentSmoothingEnabled, type: self.currentSmoothingType)
                }
                self?.delegate?.chartSettingsDidUpdate()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = smoothingAlgorithmButton
            popover.sourceRect = smoothingAlgorithmButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Preset Applications
    
    private func applyTradingPreset() {
        currentSmoothingEnabled = true
        currentSmoothingType = .savitzkyGolay
        colorThemeSegmentedControl.selectedSegmentIndex = 0 // Classic
        lineThicknessSegmentedControl.selectedSegmentIndex = 2 // Thick
        animationSpeedSegmentedControl.selectedSegmentIndex = 1 // Fast
        gridLinesSwitch.isOn = true
        
        updateAllSettings()
        showPresetAppliedMessage("Trading View Applied", "Enhanced for detailed analysis")
    }
    
    private func applySimplePreset() {
        currentSmoothingEnabled = true
        currentSmoothingType = .basic
        colorThemeSegmentedControl.selectedSegmentIndex = 0 // Classic
        lineThicknessSegmentedControl.selectedSegmentIndex = 1 // Normal
        animationSpeedSegmentedControl.selectedSegmentIndex = 2 // Normal
        gridLinesSwitch.isOn = false
        
        updateAllSettings()
        showPresetAppliedMessage("Simple View Applied", "Clean and easy to read")
    }
    
    private func applyAnalysisPreset() {
        currentSmoothingEnabled = false
        colorThemeSegmentedControl.selectedSegmentIndex = 2 // Monochrome
        lineThicknessSegmentedControl.selectedSegmentIndex = 0 // Thin
        animationSpeedSegmentedControl.selectedSegmentIndex = 1 // Fast
        gridLinesSwitch.isOn = true
        
        updateAllSettings()
        showPresetAppliedMessage("Analysis View Applied", "Raw data for technical analysis")
    }
    
    private func updateAllSettings() {
        smoothingEnabledSwitch.isOn = currentSmoothingEnabled
        updateSmoothingAlgorithmButton()
        
        // Save all settings
        UserDefaults.standard.set(gridLinesSwitch.isOn, forKey: "ChartGridLinesEnabled")
        
        let themes: [ChartColorTheme] = [.classic, .ocean, .monochrome, .accessibility]
        let selectedTheme = themes[colorThemeSegmentedControl.selectedSegmentIndex]
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "ChartColorTheme")
        
        let thicknesses: [Double] = [1.5, 2.5, 3.5, 4.5]
        let selectedThickness = thicknesses[lineThicknessSegmentedControl.selectedSegmentIndex]
        UserDefaults.standard.set(selectedThickness, forKey: "ChartLineThickness")
        
        let speeds: [Double] = [0.0, 0.3, 0.6, 1.0]
        let selectedSpeed = speeds[animationSpeedSegmentedControl.selectedSegmentIndex]
        UserDefaults.standard.set(selectedSpeed, forKey: "ChartAnimationSpeed")
        
        // Notify about smoothing changes
        delegate?.smoothingSettingsChanged(enabled: currentSmoothingEnabled, type: currentSmoothingType)
        delegate?.chartSettingsDidUpdate()
    }
    
    private func showPresetAppliedMessage(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Public Interface

extension ChartSettingsVC {
    
    func configure(smoothingEnabled: Bool, smoothingType: ChartSmoothingHelper.SmoothingType) {
        currentSmoothingEnabled = smoothingEnabled
        currentSmoothingType = smoothingType
        
        if isViewLoaded {
            loadCurrentSettings()
        }
    }
    
    var smoothingEnabled: Bool {
        return currentSmoothingEnabled
    }
    
    var smoothingType: ChartSmoothingHelper.SmoothingType {
        return currentSmoothingType
    }
} 
