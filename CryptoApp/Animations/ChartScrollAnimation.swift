//
//  ChartScrollAnimation.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

//  ChartScrollHintAnimator.swift
//  CryptoApp

import UIKit

final class ChartScrollHintAnimator {

    // Positions the arrow relative to the chart bounds
    static func layoutArrow(_ arrow: UIImageView, in bounds: CGRect) {
        arrow.frame = CGRect(
            x: bounds.midX + 60,
            y: bounds.height - 38,
            width: 18,
            height: 18
        )
    }

    // Fades in the scroll hint label and arrow
    static func fadeIn(label: UILabel, arrow: UIImageView) {
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut]) {
            label.alpha = 1
            arrow.alpha = 1
            arrow.transform = CGAffineTransform(translationX: -10, y: 0)
        }
    }

    // Applies a horizontal bounce animation to the arrow
    static func animateBounce(for arrow: UIImageView) {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            options: [.curveEaseInOut, .repeat, .autoreverse],
            animations: {
                arrow.transform = CGAffineTransform(translationX: 10, y: 0)
            }
        )
    }

    // Fades out the scroll hint label and arrow after a delay
    static func fadeOut(label: UILabel, arrow: UIImageView) {
        UIView.animate(withDuration: 0.8, delay: 2.5, options: [.curveEaseOut]) {
            label.alpha = 0
            arrow.alpha = 0
        } completion: { _ in
            arrow.layer.removeAllAnimations()
        }
    }
}
