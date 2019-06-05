//
//  ImageBrowserCell.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 23.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import ReactiveSwift
import SnapKit

class ImageBrowserCellController {
    private var disposable: Disposable?

    private let imageID: ImageEntity.ID
    private let imageManager: ImageManager
    private let statusManager: ImageStatusManager
    private weak var cell: ImageBrowserCell!

    private lazy var creationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    private lazy var creationDateIntervalFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    init(id: ImageEntity.ID, imageManager: ImageManager, statusManager: ImageStatusManager, cell: ImageBrowserCell) {
        self.imageID = id
        self.imageManager = imageManager
        self.statusManager = statusManager
        self.cell = cell

        loadImage(withID: id)
    }

    deinit {
        disposable?.dispose()
    }

    func userDidSwipeCell(left: Bool) {
        statusManager.flag(image: imageID, as: left ? .rejected : .accepted, toggle: true)
    }

    private func loadImage(withID id: ImageEntity.ID) {
        let imageEntity = imageManager.imageEntity(withID: id)

        updateLabel(withID: id)

        disposable = imageManager.fetchImage(withID: id, mode: .thumbnail).startWithResult {
            if let image = $0.value {
                DispatchQueue.main.async {
                    self.cell.imageView.image = image
                    self.cell.activityIndicator.stopAnimating()
                    self.cell.updateImageWidth()
                }
            }
        }

        if let importedImage = imageEntity as? ImportedImageEntity {
            cell.gesturesEnabled = true
            switch importedImage.status {
            case .unspecified:
                break
            case .accepted:
                cell.iconView.image = #imageLiteral(resourceName: "CheckMark")
                cell.iconView.tintColor = Constants.colors.accepted
                break
            case .rejected:
                cell.iconView.image = #imageLiteral(resourceName: "Rejected")
                cell.iconView.tintColor = Constants.colors.border
                cell.imagesView.alpha = 0.15
                break
            }
        }
    }

    private func updateLabel(withID id: ImageEntity.ID) {
        let content = ProjectGridItemLabelType.load()
        let imageEntity = imageManager.imageEntity(withID: id)

        switch content {
        case .creationTime:
            self.cell.labelView.text = imageEntity?.creationDate.flatMap { creationDateFormatter.string(from: $0) }
        case .originalFilename:
            self.cell.labelView.text = imageEntity?.originalFilename
        case .cameraSettings:
            // TODO Load the metadata but don't forget the Disposable
            self.cell.labelView.text = "TODO"
        }
    }
}

class ImageBrowserCell: UICollectionViewCell {
    var controller: ImageBrowserCellController!

    var gesturesEnabled: Bool = false

    let imagesView = UIView()
    let imageView = ShadowedImageView()
//    private let subImageView1 = ShadowedImageView()
//    private let subImageView2 = ShadowedImageView()

    let labelView = UILabel()
    let iconView = UIImageView()

    private let leftActionItem = UIImageView()
    private let rightActionItem = UIImageView()

    let activityIndicator = UIActivityIndicatorView(style: .white)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        controller = nil

        gesturesEnabled = false

        isHidden = false
        imagesView.alpha = 1

        setShadowColor(UIColor.black)

        iconView.image = nil

        imageView.image = nil
//        subImageView1.image = nil
//        subImageView2.image = nil

        imageView.resetShadow()
//        subImageView1.resetShadow()
//        subImageView2.resetShadow()

        labelView.text = nil
        activityIndicator.startAnimating()
    }

    func setShadowColor(_ shadowColor: UIColor) {
        imageView.shadowColor = shadowColor.cgColor
//        subImageView1.shadowColor = shadowColor.cgColor
//        subImageView2.shadowColor = shadowColor.cgColor
    }

    func addImageView(_ view: ShadowedImageView, subImage: Bool = false) {
        view.contentMode = .scaleAspectFit

        imagesView.addSubview(view)
        view.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalToSuperview()
        }
    }

    func setupUI() {
        addImageView(imageView)
//        addImageView(subImageView1, subImage: true)
//        addImageView(subImageView2, subImage: true)

//        let rotation = CGFloat.pi / 20
//        subImageView1.transform = CGAffineTransform(rotationAngle: rotation)
//        subImageView2.transform = CGAffineTransform(rotationAngle: -rotation)

//        imagesView.sendSubviewToBack(subImageView1)
//        imagesView.sendSubviewToBack(subImageView2)

        labelView.textColor = .white
        labelView.font = UIFont.systemFont(ofSize: 13)
        labelView.textAlignment = .center

        iconView.contentMode = .scaleAspectFit

        leftActionItem.tintColor = Constants.colors.accepted
        rightActionItem.tintColor = Constants.colors.rejected

        leftActionItem.image = #imageLiteral(resourceName: "CheckMark")
        rightActionItem.image = #imageLiteral(resourceName: "Rejected")

        leftActionItem.alpha = 0
        rightActionItem.alpha = 0

        addSubview(iconView)
        addSubview(imagesView)
        addSubview(labelView)

        iconView.snp.makeConstraints { make in
            make.right.equalTo(labelView.snp.left).inset(-Constants.spacing / 2)
            make.centerY.equalTo(labelView.snp.centerY)
            make.height.lessThanOrEqualTo(20)
        }

        imagesView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.right.equalToSuperview()
        }

        labelView.snp.makeConstraints { make in
            make.top.equalTo(imagesView.snp.bottom).offset(Constants.spacing)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(30)
        }

        activityIndicator.startAnimating()
        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(leftActionItem)
        leftActionItem.snp.makeConstraints { make in
            make.centerY.equalTo(imagesView)
            leftActionItemXConstraint = make.centerX.equalTo(imagesView).constraint
        }

        addSubview(rightActionItem)
        rightActionItem.snp.makeConstraints { make in
            make.centerY.equalTo(imagesView)
            rightActionItemXConstraint = make.centerX.equalTo(imagesView).constraint
        }

        sendSubviewToBack(leftActionItem)
        sendSubviewToBack(rightActionItem)

        let panGestureRecognizer = PanDirectionGestureRecognizer(direction: .horizontal, target: self, action: #selector(panGesture(panGestureRecognizer:)))
        imagesView.addGestureRecognizer(panGestureRecognizer)
    }

    private var leftActionItemXConstraint: Constraint!
    private var rightActionItemXConstraint: Constraint!

    @objc func panGesture(panGestureRecognizer: PanDirectionGestureRecognizer) {
        guard gesturesEnabled else {
            return
        }

        let translation = panGestureRecognizer.translation(in: imagesView)

        let distanceLimit: CGFloat = 50
        let clampedTranslation = min(max(translation.x, -distanceLimit), distanceLimit)
        let distancePercentage = clampedTranslation / distanceLimit
        let easedPercentage = sin(distancePercentage * CGFloat.pi / 2)
        let easedTranslation = distanceLimit * easedPercentage
        let actionScale = abs(easedPercentage) * 0.5 + 0.5

        let transform = CGAffineTransform(translationX: easedTranslation, y: 0)
        let actionTransform = CGAffineTransform(scaleX: actionScale, y: actionScale)

        if distancePercentage > 0 {
            leftActionItem.transform = actionTransform
            leftActionItem.alpha = easedPercentage
        } else {
            rightActionItem.transform = actionTransform
            rightActionItem.alpha = abs(easedPercentage)
        }

        switch panGestureRecognizer.state {
        case .possible:
            break
        case .began:
            imagesView.transform = transform
        case .changed:
            imagesView.transform = transform
        case .ended:
            fallthrough
        case .cancelled:
            fallthrough
        case .failed:
            fallthrough
        default:
            UIView.animate(
                withDuration: 0.5,
                animations: {
                    self.leftActionItem.alpha = 0
                    self.rightActionItem.alpha = 0
                    self.imagesView.transform = CGAffineTransform.identity
            },
                completion: { _ in
                    if abs(distancePercentage) == 1 {
                        self.controller.userDidSwipeCell(left: distancePercentage < 0)
                    }
            }
            )
        }
    }

    func updateImageWidth() {
        let coverImageWidth = imageView.imageBoundingRect?.size.width ?? 0
//        let subImage1Width = subImageView1.imageBoundingRect?.size.width ?? 0
//        let subImage2Width = subImageView2.imageBoundingRect?.size.width ?? 0
        let width = coverImageWidth // max(coverImageWidth, subImage1Width, subImage2Width)
        let offset = width / 2.5

        leftActionItemXConstraint.update(offset: -offset)
        rightActionItemXConstraint.update(offset: offset)
    }
}

//class ImageBrowserCell: UICollectionViewCell {
//    private var imageLoadDisposable: Disposable?
//
//    // TODO Move the managers to the parent by delegating
//    var imageManager: ImageManager!
//    var browsingManager: BrowsingManager!
//    var index: Int!
//    var imageListEntry: ImageListEntry! {
//        didSet {
//            switch imageListEntry! {
//            case .image(let id):
//                loadImage(withID: id)
//            case .group(let contents):
//                loadGroup(withContents: contents)
//            }
//        }
//    }
//
//    private(set) var imagesView = UIView()
//    private(set) var imageView = ShadowedImageView()
//    private var subImageView1 = ShadowedImageView()
//    private var subImageView2 = ShadowedImageView()
//
//    private var labelView = UILabel()
//    private var iconView = UIImageView()
//
//    private var leftActionItem = UIImageView()
//    private var rightActionItem = UIImageView()
//
//    private var activityIndicator = UIActivityIndicatorView(style: .white)
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupUI()
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    override func prepareForReuse() {
//        super.prepareForReuse()
//
//        isHidden = false
//        imagesView.alpha = 1
//
//        setShadowColor(UIColor.black)
//
//        iconView.image = nil
//
//        imageLoadDisposable?.dispose()
//        imageLoadDisposable = nil
//
//        imageView.image = nil
//        subImageView1.image = nil
//        subImageView2.image = nil
//
//        imageView.resetShadow()
//        subImageView1.resetShadow()
//        subImageView2.resetShadow()
//
//        labelView.text = nil
//        activityIndicator.startAnimating()
//    }
//
//    func setShadowColor(_ shadowColor: UIColor) {
//        imageView.shadowColor = shadowColor.cgColor
//        subImageView1.shadowColor = shadowColor.cgColor
//        subImageView2.shadowColor = shadowColor.cgColor
//    }
//
//    func addImageView(_ view: ShadowedImageView, subImage: Bool = false) {
//        view.contentMode = .scaleAspectFit
//
//        imagesView.addSubview(view)
//        view.snp.makeConstraints { make in
//            make.width.equalToSuperview()
//            make.height.equalToSuperview()
//        }
//    }
//
//    func setupUI() {
//        addImageView(imageView)
//        addImageView(subImageView1, subImage: true)
//        addImageView(subImageView2, subImage: true)
//
//        let rotation = CGFloat.pi / 20
//        subImageView1.transform = CGAffineTransform(rotationAngle: rotation)
//        subImageView2.transform = CGAffineTransform(rotationAngle: -rotation)
//
//        imagesView.sendSubviewToBack(subImageView1)
//        imagesView.sendSubviewToBack(subImageView2)
//
//        labelView.textColor = .white
//        labelView.font = UIFont.systemFont(ofSize: 13)
//        labelView.textAlignment = .center
//
//        iconView.contentMode = .scaleAspectFit
//
//        leftActionItem.tintColor = Constants.colors.accepted
//        rightActionItem.tintColor = Constants.colors.rejected
//
//        leftActionItem.image = #imageLiteral(resourceName: "CheckMark")
//        rightActionItem.image = #imageLiteral(resourceName: "Rejected")
//
//        leftActionItem.alpha = 0
//        rightActionItem.alpha = 0
//
//        addSubview(iconView)
//        addSubview(imagesView)
//        addSubview(labelView)
//
//        iconView.snp.makeConstraints { make in
//            make.right.equalTo(labelView.snp.left).inset(-Constants.uiPadding / 2)
//            make.centerY.equalTo(labelView.snp.centerY)
//            make.height.lessThanOrEqualTo(20)
//        }
//
//        imagesView.snp.makeConstraints { make in
//            make.top.equalToSuperview()
//            make.left.equalToSuperview()
//            make.right.equalToSuperview()
//        }
//
//        labelView.snp.makeConstraints { make in
//            make.top.equalTo(imagesView.snp.bottom).offset(Constants.uiPadding)
//            make.centerX.equalToSuperview()
//            make.bottom.equalToSuperview()
//            make.height.equalTo(30)
//        }
//
//        activityIndicator.startAnimating()
//        addSubview(activityIndicator)
//        activityIndicator.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
//
//        addSubview(leftActionItem)
//        leftActionItem.snp.makeConstraints { make in
//            make.centerY.equalTo(imagesView)
//            leftActionItemXConstraint = make.centerX.equalTo(imagesView).constraint
//        }
//
//        addSubview(rightActionItem)
//        rightActionItem.snp.makeConstraints { make in
//            make.centerY.equalTo(imagesView)
//            rightActionItemXConstraint = make.centerX.equalTo(imagesView).constraint
//        }
//
//        sendSubviewToBack(leftActionItem)
//        sendSubviewToBack(rightActionItem)
//
//        let panGestureRecognizer = PanDirectionGestureRecognizer(direction: .horizontal, target: self, action: #selector(panGesture(panGestureRecognizer:)))
//        imagesView.addGestureRecognizer(panGestureRecognizer)
//    }
//
//    private var leftActionItemXConstraint: Constraint!
//    private var rightActionItemXConstraint: Constraint!
//
//    @objc func panGesture(panGestureRecognizer: PanDirectionGestureRecognizer) {
//        let translation = panGestureRecognizer.translation(in: imagesView)
//
//        let distanceLimit: CGFloat = 50
//        let clampedTranslation = min(max(translation.x, -distanceLimit), distanceLimit)
//        let distancePercentage = clampedTranslation / distanceLimit
//        let easedPercentage = sin(distancePercentage * CGFloat.pi / 2)
//        let easedTranslation = distanceLimit * easedPercentage
//        let actionScale = abs(easedPercentage) * 0.5 + 0.5
//
//        let transform = CGAffineTransform(translationX: easedTranslation, y: 0)
//        let actionTransform = CGAffineTransform(scaleX: actionScale, y: actionScale)
//
//        if distancePercentage > 0 {
//            leftActionItem.transform = actionTransform
//            leftActionItem.alpha = easedPercentage
//        } else {
//            rightActionItem.transform = actionTransform
//            rightActionItem.alpha = abs(easedPercentage)
//        }
//
//        switch panGestureRecognizer.state {
//        case .possible:
//            break
//        case .began:
//            imagesView.transform = transform
//        case .changed:
//            imagesView.transform = transform
//        case .ended:
//            fallthrough
//        case .cancelled:
//            fallthrough
//        case .failed:
//            fallthrough
//        default:
//            UIView.animate(
//                withDuration: 0.5,
//                animations: {
//                    self.leftActionItem.alpha = 0
//                    self.rightActionItem.alpha = 0
//                    self.imagesView.transform = CGAffineTransform.identity
//                },
//                completion: { _ in
//                    if abs(distancePercentage) == 1 {
//                        self.browsingManager.setStatusOfItem(at: self.index, to: distancePercentage > 0 ? .accepted : .rejected, resetIfSame: true)
//                    }
//                }
//            )
//        }
//    }
//
//    private lazy var creationDateFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .none
//        formatter.timeStyle = .medium
//        return formatter
//    }()
//
//    private lazy var creationDateIntervalFormatter: DateIntervalFormatter = {
//        let formatter = DateIntervalFormatter()
//        formatter.dateStyle = .none
//        formatter.timeStyle = .medium
//        return formatter
//    }()
//
//    func updateLabel(withID id: ImageEntity.ID) {
//        let content = ProjectGridItemLabelType.load()
//        let imageEntity = imageManager.imageEntity(withID: id)
//
//        switch content {
//        case .creationTime:
//            self.labelView.text = imageEntity?.creationDate.flatMap { creationDateFormatter.string(from: $0) }
//        case .originalFilename:
//            self.labelView.text = imageEntity?.originalFilename
//        case .cameraSettings:
//            // TODO Load the metadata but don't forget the Disposable
//            self.labelView.text = "TODO"
//        }
//    }
//
//    func loadImage(withID id: ImageEntity.ID) {
//        let imageEntity = imageManager.imageEntity(withID: id)
//
//        updateLabel(withID: id)
//
//        imageLoadDisposable = imageManager?.fetchImage(withID: id, mode: .thumbnail).startWithResult {
//            if let image = $0.value {
//                DispatchQueue.main.async {
//                    self.imageView.image = image
//                    self.activityIndicator.stopAnimating()
//                    self.updateImageWidth()
//                }
//            }
//        }
//
//        if let importedImage = imageEntity as? ImportedImageEntity {
//            switch importedImage.status {
//            case .unspecified:
//                break
//            case .accepted:
//                iconView.image = #imageLiteral(resourceName: "CheckMark")
//                iconView.tintColor = Constants.colors.accepted
//                break
//            case .rejected:
//                iconView.image = #imageLiteral(resourceName: "Rejected")
//                iconView.tintColor = Constants.colors.border
//                imagesView.alpha = 0.15
//                break
//            }
//        }
//    }
//
//    func loadGroup(withContents contents: [ImageListEntry]) {
//        guard contents.count > 0, let imageManager = imageManager else { return }
//
//        let subImages = contents.compactMap { (entry: ImageListEntry) -> ImageEntity.ID? in
//            switch entry {
//            case .image(let id):
//                return id
//            case .group(_):
//                // Sub-groups are not supported for now
//                return nil
//            }
//        }
//
//        let previewImages = subImages.prefix(3)
//        var counter = 0
//
//        imageLoadDisposable = SignalProducer(previewImages)
//            .flatMap(.merge) { imageManager.fetchImage(withID: $0, mode: .thumbnail) }
//            .startWithResult {
//                if let image = $0.value {
//                    DispatchQueue.main.async {
//                        self.activityIndicator.stopAnimating()
//
//                        switch counter {
//                        case 0:
//                            self.imageView.image = image
//                        case 1:
//                            self.subImageView1.image = image
//                        default:
//                            self.subImageView2.image = image
//                        }
//
//                        self.updateImageWidth()
//
//                        counter += 1
//                    }
//                }
//            }
//
//        guard let first = subImages.first, let last = subImages.last else {
//            return
//        }
//
//        let firstImageEntity = imageManager.imageEntity(withID: first)
//        let lastImageEntity = imageManager.imageEntity(withID: last)
//
//        guard let startDate = firstImageEntity?.creationDate, let endDate = lastImageEntity?.creationDate else {
//            return
//        }
//
//        self.labelView.text = creationDateIntervalFormatter.string(from: startDate, to: endDate)
//    }
//
//    func updateImageWidth() {
//        let coverImageWidth = imageView.imageBoundingRect?.size.width ?? 0
//        let subImage1Width = subImageView1.imageBoundingRect?.size.width ?? 0
//        let subImage2Width = subImageView2.imageBoundingRect?.size.width ?? 0
//        let width = max(coverImageWidth, subImage1Width, subImage2Width)
//        let offset = width / 2.5
//
//        leftActionItemXConstraint.update(offset: -offset)
//        rightActionItemXConstraint.update(offset: offset)
//    }
//}
