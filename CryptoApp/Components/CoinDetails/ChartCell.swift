//
//  ChartCell.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

final class ChartCell: UITableViewCell {
    func embed(_ chartView: UIView) {
        chartView.removeFromSuperview()
        contentView.addSubview(chartView)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: contentView.topAnchor),
            chartView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            chartView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
}
