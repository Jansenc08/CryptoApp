//
//  PriceFlashHelper.swift
//  CryptoApp
//
//  Created by AI Assistant on 1/8/25.
//

import UIKit

/// Simple helper to flash price labels when they change
@objc class PriceFlashHelper: NSObject {
    
    @objc static let shared = PriceFlashHelper()
    
    private override init() {
        super.init()
    }
    
    /// Flash a price label green or red based on whether the change is positive
    /// - Parameters:
    ///   - label: The UILabel to flash
    ///   - isPositive: true for green flash (price up), false for red flash (price down)
    @objc func flashPriceLabel(_ label: UILabel, isPositive: Bool) {
        // Ensure we're on main thread
        DispatchQueue.main.async {
            // Store original color
            let originalColor = label.textColor
            
            // Set flash color
            let flashColor = isPositive ? UIColor.systemGreen : UIColor.systemRed
            
            // Flash animation
            // withDuration: How fast it changes TO green/red (make bigger = slower fade in)
            // delay: How long it STAYS green/red (make bigger = holds color longer)
            UIView.animate(withDuration: 0.3, animations: {
                label.textColor = flashColor
                label.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                    label.textColor = originalColor
                    label.transform = .identity
                }) { _ in
                    // Animation complete
                }
            }
        }
    }
} 
