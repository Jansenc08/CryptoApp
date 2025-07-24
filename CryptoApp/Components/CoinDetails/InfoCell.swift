//
//  InfoCell.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

final class InfoCell: UITableViewCell {
    let nameLabel = UILabel() // Made internal for animation access
    let rankLabel = UILabel() // Made internal for animation access
    let priceLabel = UILabel() // Made internal for animation access
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        nameLabel.font = .boldSystemFont(ofSize: 24)
        rankLabel.font = .systemFont(ofSize: 16)
        rankLabel.textColor = .secondaryLabel
        priceLabel.font = .systemFont(ofSize: 20)

        // Set Name label to be beside rank label 
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Horizontal Stack: name + rank
        let topRow = UIStackView(arrangedSubviews: [nameLabel, rankLabel])
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .firstBaseline
        topRow.distribution = .fill

        // Main Vertical Stack
        stack.axis = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(priceLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(name: String, rank: Int, price: String) {
        nameLabel.text = name
        rankLabel.text = "#\(rank)"
        priceLabel.text = price
    }
    
    /// Flash the price label when price changes
    func flashPrice(isPositive: Bool) {
        PriceFlashHelper.shared.flashPriceLabel(priceLabel, isPositive: isPositive)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
