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
    var imageManager: ImageManager!

    var imageEntities: [ImageListEntry] = [] {
        didSet {
            collectionView.reloadData()
        }
    }

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.sectionHeadersPinToVisibleBounds = true
        layout.minimumInteritemSpacing = Constants.uiPadding * 3
        layout.minimumLineSpacing = Constants.uiPadding * 3

        super.init(collectionViewLayout: layout)

        collectionView.delegate = self
        collectionView.register(ImageBrowserCell.self, forCellWithReuseIdentifier: "ImageBrowserCell")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        collectionView.backgroundColor = Constants.colors.background
        collectionView.contentInset = UIEdgeInsets(top: 2 * Constants.uiPadding, left: 4 * Constants.uiPadding, bottom: 2 * Constants.uiPadding, right: 4 * Constants.uiPadding)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageEntities.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageBrowserCell", for: indexPath)

        if let cell = cell as? ImageBrowserCell {
            cell.imageManager = imageManager
            cell.imageListEntry = imageEntities[indexPath.item]
        }

        return cell
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


