//
//  HorizontalImageBrowserViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 27.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import ReactiveSwift

protocol HorizontalImageBrowserViewControllerDelegate: class {
    func horizontalImageBrowserViewController(_ horizontalImageBrowserViewController: HorizontalImageBrowserViewController, didSelectItemAt: Int)
}

class HorizontalImageBrowserViewController: UICollectionViewController {
    private let imageManager: ImageManager
    private let browsingManager: BrowsingManager

    weak var delegate: HorizontalImageBrowserViewControllerDelegate?

    init(imageManager: ImageManager, browsingManager: BrowsingManager) {
        self.imageManager = imageManager
        self.browsingManager = browsingManager

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal

        super.init(collectionViewLayout: layout)

        browsingManager.delegate = self

        collectionView.contentInsetAdjustmentBehavior = .never

        collectionView.delegate = self
        collectionView.register(HorizontalImageBrowserCell.self, forCellWithReuseIdentifier: "HorizontalImageBrowserCell")

        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = false

        collectionView.reloadData()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // TODO Figure out why this causes simultaneous access exceptions.
//        browsingManager.delegates.removeValue(forKey: "HorizontalImageBrowserViewController")
    }

    override func viewDidLoad() {
        collectionView.backgroundColor = Constants.colors.background
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return browsingManager.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HorizontalImageBrowserCell", for: indexPath)

        if let cell = cell as? HorizontalImageBrowserCell {
            cell.imageManager = imageManager
            cell.browsingManager = browsingManager
            cell.index = indexPath.item
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.horizontalImageBrowserViewController(self, didSelectItemAt: indexPath.item)
    }
}

extension HorizontalImageBrowserViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let defaultSize: CGFloat = view.frame.height
        let entity = imageManager.imageEntity(withID: browsingManager[indexPath.item])
        let size = entity?.size ?? .zero
        let targetHeight = defaultSize
        let targetWidth = targetHeight / size.height * size.width

        return CGSize(width: targetWidth, height: targetHeight)
    }
}

extension HorizontalImageBrowserViewController: BrowsingManagerDelegate {
    func browsingManager(_ browsingManager: BrowsingManager, didUpdateItem index: Int) {
        let selection = collectionView.indexPathsForSelectedItems
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        selection?.forEach {
            collectionView.selectItem(at: $0, animated: false, scrollPosition: [])
        }
    }

    func browsingManager(_ browsingManager: BrowsingManager, didFilterItems changeSet: BrowsingManagerChangeSet) {
        // Will never be called since this BrowsingManager is intended for viewing only.
        collectionView.reloadData()
    }

    func browsingManagerDidExchangeItems(_ browsingManager: BrowsingManager) {
        collectionView.reloadData()
    }
}

// TODO Extract image loading logic to controller
class HorizontalImageBrowserCell: UICollectionViewCell {
    private var imageLoadDisposable: Disposable?

    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView()
    private let acceptedIcon = UIImageView(image: #imageLiteral(resourceName: "CheckMark"))
    private let rejectedIcon = UIImageView(image: #imageLiteral(resourceName: "Rejected"))

    var imageManager: ImageManager!
    var browsingManager: BrowsingManager!
    var index: Int! { didSet { loadImage() } }

    override var isSelected: Bool {
        didSet {
            layer.borderColor = isSelected ? UIColor.white.cgColor : Constants.colors.background.cgColor
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
        self.activityIndicator.startAnimating()
    }

    private func setupUI() {
        layer.borderWidth = 2

        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        setup(icon: acceptedIcon, color: Constants.colors.accepted)
        setup(icon: rejectedIcon, color: Constants.colors.rejected)
    }

    private func setup(icon: UIImageView, color: UIColor) {
        icon.alpha = 0
        icon.tintColor = color
        icon.layer.cornerRadius = 7.5
        icon.backgroundColor = .white
        addSubview(icon)
        icon.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(Constants.spacing / 2)
            make.right.equalToSuperview().inset(Constants.spacing / 2)
            make.width.equalTo(15)
            make.height.equalTo(15)
        }
    }

    func loadImage() {
        imageView.alpha = 1
        acceptedIcon.alpha = 0
        rejectedIcon.alpha = 0

        let id = browsingManager[index]
        imageLoadDisposable = imageManager.fetchImage(withID: id, mode: .thumbnail).startWithResult {
            if let image = $0.value {
                DispatchQueue.main.async {
                    self.imageView.image = image
                    self.activityIndicator.stopAnimating()
                }
            }
        }

        DispatchQueue.main.async {
            guard let entity = self.imageManager.imageEntity(withID: id) as? ImportedImageEntity else {
                return
            }

            switch entity.status {
            case .unspecified:
                break
            case .accepted:
                self.acceptedIcon.alpha = 1
            case .rejected:
                self.imageView.alpha = 0.15
                self.rejectedIcon.alpha = 0.25
            }
        }
    }
}
