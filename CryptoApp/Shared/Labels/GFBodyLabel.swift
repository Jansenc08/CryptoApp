//
//  CoinLabel.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//
import UIKit

class GFBodyLabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(textAlignment: NSTextAlignment, fontSize: CGFloat = 14, weight: UIFont.Weight = .regular) {
        self.init(frame: .zero)
        self.textAlignment = textAlignment
        self.font = .systemFont(ofSize: fontSize, weight: weight)
    }


    private func configure() {
        textColor = .label
        adjustsFontSizeToFitWidth = true
        adjustsFontForContentSizeCategory = true
        minimumScaleFactor = 0.8
        numberOfLines = 1
        translatesAutoresizingMaskIntoConstraints = false
    }
}

