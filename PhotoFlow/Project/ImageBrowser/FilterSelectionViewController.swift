//
//  FilterSelectionViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 02.06.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

protocol FilterSelectionViewControllerDelegate: class {
    func filterSelectionViewController(_ filterSelectionViewController: FilterSelectionViewController, didChangeFilterTo newFilter: ImageStatusFilter)
}

class FilterSelectionViewController: UITableViewController {
    private let initialFilter: ImageStatusFilter

    private let cellHeight: CGFloat = 50.0
    private let filterTitles = [
        "Accepted",
        "Rejected",
        "Unclassified"
    ]

    weak var delegate: FilterSelectionViewControllerDelegate?

    init(sourceView: UIView, currentFilter: ImageStatusFilter) {
        self.initialFilter = currentFilter
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .popover

        popoverPresentationController?.permittedArrowDirections = [.down, .up]
        popoverPresentationController?.backgroundColor = Constants.colors.lightBackground

        popoverPresentationController?.sourceView = sourceView
        popoverPresentationController?.sourceRect = sourceView.bounds

        tableView.register(FilterSelectionCell.self, forCellReuseIdentifier: "FilterSelectionCell")
        tableView.allowsMultipleSelection = true
        tableView.separatorColor = Constants.colors.border

        let footerView = FilterSelectionFooterView(frame: CGRect(origin: .zero, size: CGSize(width: 250, height: 80)))
        footerView.onReapply = {
            self.selectionChanged()
        }
        tableView.tableFooterView = footerView

        preferredContentSize = CGSize(width: 250.0, height: CGFloat(filterTitles.count) * cellHeight + footerView.frame.size.height)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        view.backgroundColor = .clear
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)


        if initialFilter.contains(.accepted) {
            selectItem(at: IndexPath(item: 0, section: 0))
        }

        if initialFilter.contains(.rejected) {
            selectItem(at: IndexPath(item: 1, section: 0))
        }

        if initialFilter.contains(.unspecified) {
            selectItem(at: IndexPath(item: 2, section: 0))
        }
    }

    func selectItem(at indexPath: IndexPath) {
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }

    func selectionChanged() {
        var filter: ImageStatusFilter = []

        if let selection = tableView.indexPathsForSelectedRows?.map({ $0.item }) {
            for i in selection {
                switch i {
                case 0:
                    filter.formUnion(.accepted)
                case 1:
                    filter.formUnion(.rejected)
                case 2:
                    filter.formUnion(.unspecified)
                default:
                    break
                }
            }
        }

        delegate?.filterSelectionViewController(self, didChangeFilterTo: filter)
    }
}

extension FilterSelectionViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filterTitles.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        selectionChanged()
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
        selectionChanged()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FilterSelectionCell", for: indexPath)

        if let cell = cell as? FilterSelectionCell {
            cell.title = filterTitles[indexPath.item]
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
    }
}

class FilterSelectionFooterView: UIStackView {
    let reapplyButton = UIButton(type: .system)
    let label = UILabel()

    var onReapply: (() -> ())?

    override init(frame: CGRect) {
        super.init(frame: frame)

        reapplyButton.setTitle("Reapply filters", for: .normal)
        reapplyButton.addTarget(self, action: #selector(onReapplyClick), for: .touchUpInside)
        reapplyButton.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        label.text = "Filters are not updated automatically to ease the selection workflow."
        label.textColor = Constants.colors.border
        label.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        axis = .vertical
        alignment = .center
        distribution = .fill
        spacing = Constants.spacing
        layoutMargins = Constants.insets
        isLayoutMarginsRelativeArrangement = true

        addArrangedSubview(reapplyButton)
        addArrangedSubview(label)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func onReapplyClick() {
        onReapply?()
    }
}

class FilterSelectionCell: UITableViewCell {
    private let titleLabel = UILabel()

    var title: String! {
        didSet {
            titleLabel.text = title
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear

        titleLabel.textColor = .lightGray
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }
}
