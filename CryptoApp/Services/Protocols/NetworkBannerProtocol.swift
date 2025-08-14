import UIKit

/**
 * NetworkBannerDelegate
 *
 * Protocol for view controllers that can display network connectivity banners.
 * Allows for proper positioning within each view controller's layout.
 */
protocol NetworkBannerDelegate: AnyObject {
    /**
     * Show the network banner in the appropriate position within the view controller
     */
    func showNetworkBanner()
    
    /**
     * Hide the network banner from the view controller
     */
    func hideNetworkBanner()
}
