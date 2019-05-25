//
//  ImageBrowserCell.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 23.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import ReactiveSwift

class ImageBrowserCell: UICollectionViewCell {
    private var imageLoadDisposable: Disposable?

    var imageManager: ImageManager!
    var imageListEntry: ImageListEntry! {
        didSet {
            switch imageListEntry! {
            case .image(let id):
                loadImage(withID: id)
            case .group(let contents):
                loadGroup(withContents: contents)
            }
        }
    }

    private var imagesView = UIView()
    private var imageView = ShadowedImageView()
    private var subImageView1 = ShadowedImageView()
    private var subImageView2 = ShadowedImageView()
    private var labelView = UILabel()

    private var activityIndicator = UIActivityIndicatorView(style: .white)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadDisposable?.dispose()
        imageLoadDisposable = nil

        imageView.image = nil
        subImageView1.image = nil
        subImageView2.image = nil

        imageView.resetShadow()
        subImageView1.resetShadow()
        subImageView2.resetShadow()

        labelView.text = nil
        activityIndicator.startAnimating()
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
        addImageView(subImageView1, subImage: true)
        addImageView(subImageView2, subImage: true)

        let rotation = CGFloat.pi / 20
        subImageView1.transform = CGAffineTransform(rotationAngle: rotation)
        subImageView2.transform = CGAffineTransform(rotationAngle: -rotation)

        imagesView.sendSubviewToBack(subImageView1)
        imagesView.sendSubviewToBack(subImageView2)

        labelView.textColor = .white
        labelView.font = UIFont.systemFont(ofSize: 13)
        labelView.textAlignment = .center

        addSubview(imagesView)
        addSubview(labelView)

        imagesView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.right.equalToSuperview()
        }

        labelView.snp.makeConstraints { make in
            make.top.equalTo(imagesView.snp.bottom).offset(Constants.uiPadding)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(30)
        }

        activityIndicator.startAnimating()
        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

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

    func loadImage(withID id: ImageEntity.ID) {
        let imageEntity = imageManager.imageEntity(withID: id)
        self.labelView.text = imageEntity?.creationDate.flatMap { creationDateFormatter.string(from: $0) }

        imageLoadDisposable = imageManager?.fetchImage(withID: id, thumbnail: true).startWithResult {
            if let image = $0.value {
                DispatchQueue.main.async {
                    self.imageView.image = image
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }

    func loadGroup(withContents contents: [ImageListEntry]) {
        guard contents.count > 0, let imageManager = imageManager else { return }

        let subImages = contents.compactMap { (entry: ImageListEntry) -> ImageEntity.ID? in
            switch entry {
            case .image(let id):
                return id
            case .group(_):
                // Sub-groups are not supported for now
                return nil
            }
        }

        let previewImages = subImages.prefix(3)
        var counter = 0

        imageLoadDisposable = SignalProducer(previewImages)
            .flatMap(.merge) { imageManager.fetchImage(withID: $0, thumbnail: true) }
            .startWithResult {
                if let image = $0.value {
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()

                        switch counter {
                        case 0:
                            self.imageView.image = image
                        case 1:
                            self.subImageView1.image = image
                        default:
                            self.subImageView2.image = image
                        }

                        counter += 1
                    }
                }
            }

        guard let first = subImages.first, let last = subImages.last else {
            return
        }

        let firstImageEntity = imageManager.imageEntity(withID: first)
        let lastImageEntity = imageManager.imageEntity(withID: last)

        guard let startDate = firstImageEntity?.creationDate, let endDate = lastImageEntity?.creationDate else {
            return
        }

        self.labelView.text = creationDateIntervalFormatter.string(from: startDate, to: endDate)
    }
}
