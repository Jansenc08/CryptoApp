import UIKit

final class StatsCell: UITableViewCell {

    private let segmentView = SegmentView()
    private let cardView = UIView()
    private let stackView = UIStackView()

    private var leftColumn = UIStackView()
    private var rightColumn = UIStackView()

    private var onSegmentChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let headerLabel:UILabel = {
        let label  = UILabel()
        label.text = "Statistics >"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .label
        label.isUserInteractionEnabled = true
        return label
    }()

    private func setupUI() {
        selectionStyle = .none
        contentView.backgroundColor = .clear

        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4

        contentView.addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        // SegmentView style
        segmentView.translatesAutoresizingMaskIntoConstraints = false
        segmentView.heightAnchor.constraint(equalToConstant: 28).isActive = true
        segmentView.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let segmentWrapper = UIView()
        segmentWrapper.addSubview(segmentView)
        segmentView.trailingAnchor.constraint(equalTo: segmentWrapper.trailingAnchor).isActive = true
        segmentView.topAnchor.constraint(equalTo: segmentWrapper.topAnchor).isActive = true
        segmentView.bottomAnchor.constraint(equalTo: segmentWrapper.bottomAnchor).isActive = true
        segmentView.leadingAnchor.constraint(greaterThanOrEqualTo: segmentWrapper.leadingAnchor).isActive = true

        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        
        let headerStack = UIStackView(arrangedSubviews: [headerLabel, segmentWrapper])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center

        let verticalStack = UIStackView(arrangedSubviews: [headerStack, stackView])
        verticalStack.axis = .vertical
        verticalStack.spacing = 20

        cardView.addSubview(verticalStack)
        verticalStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            verticalStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            verticalStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            verticalStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            verticalStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    func configure(with stats: [StatItem], selectedRange: String = "24h", onSegmentChange: @escaping (String) -> Void) {
        self.onSegmentChange = onSegmentChange

        // Configure segment view with selected range
        let options = ["24h", "30d", "1y"]
        let selectedIndex = options.firstIndex(of: selectedRange) ?? 0
        
        segmentView.configure(withItems: options)
        segmentView.setSelectedIndex(selectedIndex) // Set the correct selected segment
        segmentView.onSelectionChanged = { [weak self] index in
            self?.onSegmentChange?(options[index])
        }

        // Clear previous rows
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Add each stat as a horizontal row
        for item in stats {
            let row = makeStatRow(for: item)
            stackView.addArrangedSubview(row)
        }
    }


    private func makeStatRow(for item: StatItem) -> UIView {
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = item.title

        let valueLabel = UILabel()
        valueLabel.font = .boldSystemFont(ofSize: 13)
        valueLabel.textColor = item.valueColor ?? .label // Use valueColor if available, otherwise default
        valueLabel.text = item.value
        valueLabel.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.axis = .horizontal
        row.distribution = .equalSpacing
        return row
    }

}
