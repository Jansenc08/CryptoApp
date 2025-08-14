import UIKit
import Combine

/**
 * NetworkBannerService
 *
 * Centralized service for managing the network connectivity banner.
 * Automatically shows/hides the banner based on connectivity status.
 *
 * Features:
 * - Global banner management across all screens
 * - Immediate banner dismissal when connection returns
 * - Thread-safe singleton pattern
 * - Smooth animations for show/hide
 */
final class NetworkBannerService {
    
    // MARK: - Singleton
    
    static let shared = NetworkBannerService()
    private init() {}
    
    // MARK: - Private Properties
    
    private weak var currentBanner: NetworkBannerView?
    private weak var targetWindow: UIWindow?
    private var connectivityCancellable: AnyCancellable?
    
    // MARK: - Public Methods
    
    /**
     * Start monitoring connectivity and managing banner display
     * Should be called once during app initialization
     */
    func startMonitoring(in window: UIWindow, with monitor: NetworkConnectivityMonitor) {
        self.targetWindow = window
        
        // Cancel any existing subscription first
        connectivityCancellable?.cancel()
        
        // Subscribe to connectivity changes
        connectivityCancellable = monitor.connectivityPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                AppLogger.ui("📶 NetworkBannerService: Connectivity changed to \(isConnected ? "CONNECTED" : "DISCONNECTED")")
                if isConnected {
                    AppLogger.ui("📶 NetworkBannerService: Hiding banner (connected)")
                    self?.hideBanner()
                } else {
                    AppLogger.ui("📶 NetworkBannerService: Showing banner (disconnected)")
                    self?.showBanner()
                }
            }
        
        // Check initial state and set banner accordingly
        let initialState = monitor.isConnected
        AppLogger.ui("📶 NetworkBannerService: Initial connectivity state: \(initialState ? "CONNECTED" : "DISCONNECTED")")
        if initialState {
            AppLogger.ui("📶 NetworkBannerService: Initial state connected - ensuring banner is hidden")
            hideBanner()
        } else {
            AppLogger.ui("📶 NetworkBannerService: Initial state disconnected - showing banner")
            showBanner()
        }
        
        AppLogger.ui("NetworkBannerService started monitoring")
    }
    
    /**
     * Stop monitoring and clean up
     */
    func stopMonitoring() {
        connectivityCancellable?.cancel()
        connectivityCancellable = nil
        hideBanner()
        
        AppLogger.ui("NetworkBannerService stopped monitoring")
    }
    
    // MARK: - Private Methods
    
    private func showBanner() {
        AppLogger.ui("🔴 NetworkBannerService: showBanner() called")
        guard let window = targetWindow else { 
            AppLogger.ui("🔴 NetworkBannerService: No target window - cannot show banner")
            return 
        }
        
        // Don't show if already visible
        if let existing = currentBanner, existing.superview != nil {
            AppLogger.ui("🔴 NetworkBannerService: Banner already visible - skipping")
            return
        }
        
        AppLogger.ui("🔴 NetworkBannerService: Creating and showing new banner")
        let banner = NetworkBannerView()
        banner.alpha = 0
        banner.translatesAutoresizingMaskIntoConstraints = false
        
        window.addSubview(banner)
        currentBanner = banner
        
        // Position at top of window
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            banner.topAnchor.constraint(equalTo: window.topAnchor)
        ])
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            banner.alpha = 1
        }
        
        AppLogger.ui("🔴 Network banner shown")
    }
    
    private func hideBanner() {
        AppLogger.ui("✅ NetworkBannerService: hideBanner() called")
        guard let banner = currentBanner else { 
            AppLogger.ui("✅ NetworkBannerService: No banner to hide")
            return 
        }
        
        AppLogger.ui("✅ NetworkBannerService: Hiding banner IMMEDIATELY")
        // Immediate hide - no animation for faster response
        banner.removeFromSuperview()
        currentBanner = nil
        AppLogger.ui("✅ Network banner hidden immediately")
    }
}