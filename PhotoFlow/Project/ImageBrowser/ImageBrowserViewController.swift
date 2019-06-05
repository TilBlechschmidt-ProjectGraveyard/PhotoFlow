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
    // TODO Remove document and image manager
    private let document: ProjectDocument
    private let imageManager: ImageManager
    private let statusManager: ImageStatusManager

    private let browsingManagers: [BrowsingManager]

    init(document: ProjectDocument) {
        self.document = document
        self.imageManager = document.imageManager
        self.statusManager = document.statusManager
        self.browsingManagers = [
            BrowsingManager(imageManager: imageManager, statusManager: statusManager),
            BrowsingManager(imageManager: imageManager, statusManager: statusManager)
        ]

        let layout = UICollectionViewFlowLayout()
        layout.sectionHeadersPinToVisibleBounds = true
        layout.minimumInteritemSpacing = Constants.spacing * 3
        layout.minimumLineSpacing = Constants.spacing * 3
        layout.headerReferenceSize = CGSize(width: 100, height: 65)

        super.init(collectionViewLayout: layout)

        browsingManagers.forEach { $0.delegate = self }
        collectionView.delegate = self
        collectionView.register(ImageBrowserCell.self, forCellWithReuseIdentifier: "ImageBrowserCell")
        collectionView.register(ImageBrowserSupplimentaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageBrowserSupplimentaryView")

        imageManager.imageIDs(for: .imported).startWithResult { result in
            if let imageIDs = result.value {
                self.browsingManagers[0].images = imageIDs
            }
        }

        imageManager.imageIDs(for: .edited).startWithResult { result in
            if let imageIDs = result.value {
                self.browsingManagers[1].images = imageIDs
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        collectionView.backgroundColor = Constants.colors.background
    }
}

extension ImageBrowserViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return browsingManagers.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return browsingManagers[section].count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageBrowserCell", for: indexPath)

        if let cell = cell as? ImageBrowserCell {
            let imageID = browsingManagers[indexPath.section][indexPath.item]
            let controller = ImageBrowserCellController(id: imageID, imageManager: imageManager, statusManager: statusManager, cell: cell)
            cell.controller = controller
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let cell = collectionView.cellForItem(at: indexPath) as? ImageBrowserCell else {
            return
        }

        let frame = cell.imageView.bounds

        let viewerVC = ImageViewerViewController(imageManager: imageManager, statusManager: statusManager, browsingManager: browsingManagers[indexPath.section].createCopy(), index: indexPath.item)
        let cellFrameInTargetCoordinateSystem = viewerVC.view.convert(frame, from: cell.imageView)

        let navigationController = UINavigationController(rootViewController: viewerVC)
        navigationController.navigationBar.barStyle = .blackTranslucent
        navigationController.modalPresentationStyle = .overFullScreen
        navigationController.modalPresentationCapturesStatusBarAppearance = true

        present(navigationController, animated: false) {
            cell.isHidden = true
            viewerVC.beginTransition(from: cellFrameInTargetCoordinateSystem) {
                cell.isHidden = false
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "ImageBrowserSupplimentaryView", for: indexPath)

            if let view = view as? ImageBrowserSupplimentaryView {
                view.title = indexPath.section == 0 ? "Imported" : "Edited"

                if indexPath.section == 0 {
                    view.rightButtonTitle = "Filter"
                    view.rightButtonCallback = {
                        let currentFilter = self.browsingManagers[0].filters.first as? ImageStatusFilter ?? ImageStatusFilter.all
                        let vc = FilterSelectionViewController(sourceView: view.rightButton, currentFilter: currentFilter)
                        vc.delegate = self
                        self.present(vc, animated: true)
                    }
                }
            }

            return view
        default:
            return UICollectionReusableView()
        }
    }
}

extension ImageBrowserViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 2 * Constants.spacing, left: 4 * Constants.spacing, bottom: 2 * Constants.spacing, right: 4 * Constants.spacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 200, height: 200)
    }
}

extension ImageBrowserViewController: FilterSelectionViewControllerDelegate {
    func filterSelectionViewController(_ filterSelectionViewController: FilterSelectionViewController, didChangeFilterTo newFilter: ImageStatusFilter) {
        browsingManagers[0].filters = [newFilter]
    }
}

extension ImageBrowserViewController: BrowsingManagerDelegate {
    func browsingManager(_ browsingManager: BrowsingManager, didUpdateItem index: Int) {
        DispatchQueue.main.async {
            guard let section = self.browsingManagers.firstIndex(where: { $0 == browsingManager }) else {
                return
            }

            self.collectionView.reloadItems(at: [IndexPath(item: index, section: section)])
        }
    }

    func browsingManagerDidExchangeItems(_ browsingManager: BrowsingManager) {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    func browsingManager(_ browsingManager: BrowsingManager, didFilterItems changeSet: BrowsingManagerChangeSet) {
        DispatchQueue.main.async {
            guard let section = self.browsingManagers.firstIndex(where: { $0 == browsingManager }) else {
                return
            }

            self.collectionView.performBatchUpdates({
                for change in changeSet {
                    switch change {
                    case .insert(let index):
                        self.collectionView.insertItems(at: [IndexPath(item: index, section: section)])
                    case .remove(let index):
                        self.collectionView.deleteItems(at: [IndexPath(item: index, section: section)])
                    case .update(_):
                        // TODO Update item at index
                        break
                    }
                }
            }, completion: nil)
        }
    }
}
