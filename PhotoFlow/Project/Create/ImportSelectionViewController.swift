//
//  CreateViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import Photos
import SnapKit

protocol ImportSelectionViewControllerDelegate: class {
    func createViewController(_ createViewController: ImportSelectionViewController, didImport assets: [PHAsset])
}

class ImportSelectionViewController: UIViewController {
    private let collectionView: UICollectionView

    private let titleView = UILabel()
    private let subtitleView = UILabel()

    private let importManager: ImportManager

    private let groups: [[PHAsset]]
    private var groupSelectionCounter: [Int] {
        didSet {
            let selectedAssets = self.selectedAssets
            let selectedItemCount = collectionView.indexPathsForSelectedItems?.count ?? 0
            let itemsSelected = selectedItemCount > 0

            titleView.text = itemsSelected ? "\(selectedItemCount) Photos Selected" : "Import"
            subtitleView.text = "Calculating size ..."
            navigationItem.rightBarButtonItem?.isEnabled = itemsSelected

            DispatchQueue.global(qos: .userInitiated).async {
                let byteFormatter = ByteCountFormatter()
                let bytes = self.importManager.accumulatedFileSize(for: selectedAssets)

                DispatchQueue.main.async {
                    self.subtitleView.text = itemsSelected ? byteFormatter.string(fromByteCount: bytes) : ""
                }
            }
        }
    }

    weak var delegate: ImportSelectionViewControllerDelegate?

    init(importManager: ImportManager) {
        self.importManager = importManager
        self.groups = importManager.recentGroups()
        self.groupSelectionCounter = Array(repeating: 0, count: groups.count)

        let layout = UICollectionViewFlowLayout()
        layout.sectionHeadersPinToVisibleBounds = true
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        layout.itemSize = CGSize(width: 160, height: 90)
        layout.headerReferenceSize = CGSize(width: 100, height: 50)

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)

        titleView.text = "Import"
        view.backgroundColor = Constants.colors.background
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        collectionView.register(CreateViewCell.self, forCellWithReuseIdentifier: "CreateViewCell")
        collectionView.register(CreateViewSupplimentaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "CreateViewSupplimentaryView")

        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = true

        view = collectionView
        view.backgroundColor = .clear

        titleView.font = UIFont.boldSystemFont(ofSize: 18)
        subtitleView.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        titleView.textColor = .white
        subtitleView.textColor = .lightGray

        let navbarTitleStackView = UIStackView(arrangedSubviews: [titleView, subtitleView])
        navbarTitleStackView.axis = .vertical
        navbarTitleStackView.alignment = .center
        navbarTitleStackView.distribution = .fill
        navbarTitleStackView.spacing = Constants.spacing / 4
        navigationItem.titleView = navbarTitleStackView


    }

    override func viewDidLoad() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Import", style: .done, target: self, action: #selector(importTapped))

        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    var selectedAssets: [PHAsset] {
        let selectedIndexPaths = collectionView.indexPathsForSelectedItems ?? []
        return selectedIndexPaths.map { groups[$0.section][$0.item] }
    }

    @objc func importTapped() {
        delegate?.createViewController(self, didImport: selectedAssets)
    }

    func title(for section: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd.MM.yyyy"

        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "HH:mm"

        let group = groups[section]

        if let startDate = group.first?.creationDate, let endDate = group.last?.creationDate {
            let isOnSameDay = Calendar.current.isDate(startDate, inSameDayAs: endDate)
            let startDateString = (isOnSameDay ? shortFormatter : formatter).string(from: startDate)
            let endDateString = formatter.string(from: endDate)

            return "\(startDateString) - \(endDateString)"
        } else {
            return "Unknown date."
        }
    }

    func updateSupplementaryViewButton(in section: Int) {
        let supplimentaryViewIndexPath = IndexPath(row: 0, section: section)
        let view = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: supplimentaryViewIndexPath)
        if let view = view as? CreateViewSupplimentaryView {
            view.displayUnselect = groupSelectionCounter[section] == self.collectionView(collectionView, numberOfItemsInSection: section)
        }
    }
}

extension ImportSelectionViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: Constants.spacing, left: Constants.spacing * 2, bottom: Constants.spacing * 4, right: Constants.spacing * 2)
    }
}

extension ImportSelectionViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return groups.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return groups[section].count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CreateViewCell", for: indexPath)

        if let cell = cell as? CreateViewCell {
            cell.manager = importManager.imageManager
            cell.asset = groups[indexPath.section][indexPath.row]
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "CreateViewSupplimentaryView", for: indexPath)

            if let view = view as? CreateViewSupplimentaryView {
                let section = indexPath.section
                view.title = self.title(for: section)
                view.displayUnselect = groupSelectionCounter[section] == self.collectionView(collectionView, numberOfItemsInSection: section)
                view.buttonClosure = {
                    let numberOfItems = self.collectionView(collectionView, numberOfItemsInSection: section)
                    let indexPaths = (0..<numberOfItems).map { IndexPath(item: $0, section: section) }

                    if view.displayUnselect {
                        indexPaths.forEach {
                            collectionView.deselectItem(at: $0, animated: true)
                        }
                        self.groupSelectionCounter[section] = 0
                    } else {
                        indexPaths.forEach {
                            collectionView.selectItem(at: $0, animated: true, scrollPosition: [])
                        }
                        self.groupSelectionCounter[section] = numberOfItems
                    }

                    self.updateSupplementaryViewButton(in: section)
                }
            }

            return view
        default:
            return UICollectionReusableView()
        }
    }
}

extension ImportSelectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        groupSelectionCounter[indexPath.section] += 1
        updateSupplementaryViewButton(in: indexPath.section)
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        groupSelectionCounter[indexPath.section] -= 1
        updateSupplementaryViewButton(in: indexPath.section)
    }
}

class CreateViewCell: UICollectionViewCell {
    private var imageView = UIImageView()
    private var requestID: PHImageRequestID?

    private let selectedOverlay = UIView()
    private let checkmark = UIImageView(image: #imageLiteral(resourceName: "CheckMark"))

    override var isSelected: Bool {
        didSet {
            selectedOverlay.alpha = isSelected ? 1 : 0
        }
    }

    var manager: PHImageManager!

    // TODO Move image fetching to controller
    var asset: PHAsset! {
        didSet {
            let option = PHImageRequestOptions()
            option.deliveryMode = .opportunistic
            option.isNetworkAccessAllowed = true

            self.requestID = manager.requestImage(for: asset, targetSize: CGSize(width: 160, height: 90), contentMode: .aspectFill, options: option, resultHandler: { (result, info) -> Void in
                self.imageView.image = result
            })
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        requestID.flatMap { manager.cancelImageRequest($0) }
        requestID = nil
    }

    func setupUI() {
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        selectedOverlay.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        addSubview(selectedOverlay)
        selectedOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        checkmark.layer.masksToBounds = true
        checkmark.backgroundColor = .white
        checkmark.contentMode = .scaleAspectFill
        checkmark.tintColor = Constants.colors.blue
        selectedOverlay.addSubview(checkmark)
        checkmark.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10)
            make.right.equalToSuperview().inset(10)
            make.width.equalTo(25)
            make.height.equalTo(25)
        }

        isSelected = false
    }

    override func layoutSubviews() {
        checkmark.layer.cornerRadius = checkmark.frame.size.width / 2
    }
}

class CreateViewSupplimentaryView: UICollectionReusableView {
    private var titleLabel = UILabel()
    private var selectButton = UIButton(type: .system)

    var buttonClosure: (() -> ())? = nil

    var title: String! {
        didSet {
            titleLabel.text = title
        }
    }

    var displayUnselect: Bool = false {
        didSet {
            if displayUnselect {
                selectButton.setTitle("Deselect", for: .normal)
            } else {
                selectButton.setTitle("Select", for: .normal)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        displayUnselect = false
    }

    func setupUI() {
        blur(style: .dark)

        titleLabel.textColor = .white

        selectButton.addTarget(self, action: #selector(buttonClicked), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [titleLabel, selectButton])

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview()
            make.right.equalToSuperview().inset(20)
            make.left.equalToSuperview().inset(20)
        }
    }

    @objc func buttonClicked() {
        buttonClosure?()
    }
}
