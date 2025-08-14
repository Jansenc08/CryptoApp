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
 * - Proper positioning within view controller layouts
 */
final class NetworkBannerService {
    
    // MARK: - Singleton
    
    static let shared = NetworkBannerService()
    private init() {}
    
    // MARK: - Private Properties
    
    private var connectivityCancellable: AnyCancellable?
    private var activeViewControllers: NSHashTable<UIViewController> = NSHashTable.weakObjects()
    
    // MARK: - Public Methods
    
    /**
     * Start monitoring connectivity and managing banner display
     * Should be called once during app initialization
     */
    func startMonitoring(with monitor: NetworkConnectivityMonitor) {
        // Cancel any existing subscription first
        connectivityCancellable?.cancel()
        
        // Subscribe to connectivity changes
        connectivityCancellable = monitor.connectivityPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.hideAllBanners()
                } else {
                    self?.showAllBanners()
                }
            }
        
        AppLogger.ui("NetworkBannerService started monitoring")
    }
    
    /**
     * Register a view controller to receive banner updates
     */
    func registerViewController(_ viewController: UIViewController & NetworkBannerDelegate) {
        activeViewControllers.add(viewController)
        
        // Always hide banner first to prevent flashing
        viewController.hideNetworkBanner()
        
        // Check current connectivity and show/hide banner accordingly
        if let monitor = getCurrentMonitor() {
            // Wait longer for initial connectivity test to complete on app launch
            let delay: TimeInterval = monitor.hasCompletedInitialTest ? 0.1 : 1.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let currentMonitor = self.getCurrentMonitor() {
                    let isConnected = currentMonitor.isConnected
                    
                    if !isConnected {
                        viewController.showNetworkBanner()
                    }
                }
            }
        }
    }
    
    /**
     * Unregister a view controller from banner updates
     */
    func unregisterViewController(_ viewController: UIViewController) {
        activeViewControllers.remove(viewController)

    }
    
    private func getCurrentMonitor() -> NetworkConnectivityMonitor? {
        return Dependencies.container.networkConnectivityMonitor()
    }
    
    /**
     * Stop monitoring and clean up
     */
    func stopMonitoring() {
        connectivityCancellable?.cancel()
        connectivityCancellable = nil
        hideAllBanners()
        
        AppLogger.ui("NetworkBannerService stopped monitoring")
    }
    
    // MARK: - Private Methods
    
    private func showAllBanners() {
        for viewController in activeViewControllers.allObjects {
            if let bannerDelegate = viewController as? NetworkBannerDelegate {
                bannerDelegate.showNetworkBanner()
            }
        }
    }
    
    private func hideAllBanners() {
        for viewController in activeViewControllers.allObjects {
            if let bannerDelegate = viewController as? NetworkBannerDelegate {
                bannerDelegate.hideNetworkBanner()
            }
        }
    }
}