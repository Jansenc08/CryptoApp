//
//  SegmentCell.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//

final class SegmentCell: UITableViewCell {
    private let container = UIView()
    private let segmentView = SegmentView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(container)
                container.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                    container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                    container.topAnchor.constraint(equalTo: contentView.topAnchor),
                    container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
                ])

                container.addSubview(segmentView)
                segmentView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    segmentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    segmentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    segmentView.topAnchor.constraint(equalTo: container.topAnchor),
                    segmentView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                ])
    }

    func configure(items: [String], onSelect: @escaping (String) -> Void) {
        segmentView.configure(withItems: items)
        segmentView.onSelectionChanged = { index in
            onSelect(items[index])
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}
