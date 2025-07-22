//
//  ChartScrollAnimation.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

//  ChartScrollHintAnimator.swift
//  CryptoApp

import UIKit

// MARK: - Chart Scroll Hint Animator

class ChartScrollHintAnimator {
    
    static func fadeIn(label: UILabel, arrow: UIImageView) {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut) {
            label.alpha = 0.8
            arrow.alpha = 0.6
        }
    }
    
    static func fadeOut(label: UILabel, arrow: UIImageView) {
        UIView.animate(withDuration: 0.5, delay: 3.0, options: .curveEaseIn) {
            label.alpha = 0
            arrow.alpha = 0
        }
    }
    
    static func animateBounce(for view: UIView) {
        UIView.animate(withDuration: 0.6, delay: 0.5, options: [.repeat, .autoreverse]) {
            view.transform = CGAffineTransform(translationX: 10, y: 0)
        } completion: { _ in
            view.transform = .identity
        }
    }
    
    static func layoutArrow(_ arrowView: UIImageView, in bounds: CGRect) {
        let arrowSize: CGFloat = 16
        arrowView.frame = CGRect(
            x: bounds.width - arrowSize - 20,
            y: bounds.height - arrowSize - 8,
            width: arrowSize,
            height: arrowSize
        )
    }
}
