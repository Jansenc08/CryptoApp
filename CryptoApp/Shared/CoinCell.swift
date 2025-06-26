//
//  CoinCell.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import UIKit

final class CoinCell: UICollectionViewCell {
    
    static let reuseID = "CoinCell"
    
    private let rankLabel = GFBodyLabel(textAlignment: .left, fontSize: 14, weight: .semibold)
    private let nameLabel = GFBodyLabel(textAlignment: .left, fontSize: 14)
    private let priceLabel = GFBodyLabel(textAlignment: .right, fontSize: 14, weight: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with coin: Coin) {
        rankLabel.text = "\(coin.cmcRank)"
        nameLabel.text = "\(coin.name) (\(coin.symbol))"
        if let price = coin.quote?["USD"]?.price {
            priceLabel.text = String(format: "$%.2f", price)
        } else {
            priceLabel.text = "N/A"
        }
    }

     func configure() {
        let stack = UIStackView(arrangedSubviews: [rankLabel, nameLabel, priceLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
}
