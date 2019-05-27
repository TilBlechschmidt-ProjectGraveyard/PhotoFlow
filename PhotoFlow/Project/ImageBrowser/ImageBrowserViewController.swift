//
//  ImageBrowserViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 23.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import ReactiveSwift

class ImageBrowserViewController: UICollectionViewController {
    private let document: ProjectDocument
    private let imageManager: ImageManager
    private let browsingManager: BrowsingManager

//    var imageEntities: [ImageListEntry] = [] {
//        didSet {
//            collectionView.reloadData()
//        }
//    }

    init(document: ProjectDocument) {
        self.document = document
        self.imageManager = document.imageManager
        self.browsingManager = BrowsingManager(imageManager: imageManager)

        let layout = UICollectionViewFlowLayout()
        layout.sectionHeadersPinToVisibleBounds = true
        layout.minimumInteritemSpacing = Constants.uiPadding * 3
        layout.minimumLineSpacing = Constants.uiPadding * 3

        super.init(collectionViewLayout: layout)

        browsingManager.delegate = self
        collectionView.delegate = self
        collectionView.register(ImageBrowserCell.self, forCellWithReuseIdentifier: "ImageBrowserCell")

        browsingManager.loadImages()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        collectionView.backgroundColor = Constants.colors.background
        collectionView.contentInset = UIEdgeInsets(top: 2 * Constants.uiPadding, left: 4 * Constants.uiPadding, bottom: 2 * Constants.uiPadding, right: 4 * Constants.uiPadding)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return browsingManager.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageBrowserCell", for: indexPath)

        if let cell = cell as? ImageBrowserCell {
            cell.imageManager = imageManager
            cell.browsingManager = browsingManager
            cell.index = indexPath.item
            cell.imageListEntry = browsingManager[indexPath.item]
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let cell = collectionView.cellForItem(at: indexPath) as? ImageBrowserCell else {
            return
        }

        let frame = cell.imageView.bounds
        var imageID: ImageEntity.ID

        switch browsingManager[indexPath.item] {
        case .image(let id):
            imageID = id
        case .group(let contents):
            guard let first = contents.first else { return }
            switch first {
            case .image(let id):
                imageID = id
            default:
                return
            }
        }

        let viewerVC = ImageViewerViewController(document: document, imageID: imageID)
        let cellFrameInTargetCoordinateSystem = viewerVC.view.convert(frame, from: cell.imageView)

        let navigationController = UINavigationController(rootViewController: viewerVC)
        navigationController.navigationBar.barStyle = .blackTranslucent
        navigationController.modalPresentationStyle = .overFullScreen

        present(navigationController, animated: false) {
            cell.isHidden = true
            viewerVC.beginTransition(from: cellFrameInTargetCoordinateSystem) {
                cell.isHidden = false
            }
        }
    }
}

extension ImageBrowserViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

//        let defaultSize: CGFloat = 200.0
//        let size = imageEntities[indexPath.item].size
//        let targetHeight = defaultSize
//        let targetWidth = targetHeight / size.height * size.width

//        return CGSize(width: targetWidth, height: targetHeight)
        return CGSize(width: 200, height: 200)
    }
}

extension ImageBrowserViewController: BrowsingManagerDelegate {
    func browsingManager(_ browsingManager: BrowsingManager, didChangeItemWithIndex index: Int) {
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }

    func browsingManager(_ browsingManager: BrowsingManager, didLoadImageListEntries entries: [ImageListEntry]) {
        collectionView.insertItems(at: entries.indices.map { IndexPath(item: $0, section: 0) })
    }
}
