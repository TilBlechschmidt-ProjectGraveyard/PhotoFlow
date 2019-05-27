//
//  CreateNavigationController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import Photos
import ReactiveSwift

enum DocumentCreationError: Error {
    case unableToSave
    case unableToOpen
    case unableToClose
}

class CreateNavigationController: UINavigationController {
    private let importHandler: (URL?, UIDocumentBrowserViewController.ImportMode) -> Void
    private let importManager: ImportManager

    init(importManager: ImportManager, importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        self.importHandler = importHandler
        self.importManager = importManager

        super.init(nibName: nil, bundle: nil)

        let namingViewController = NamingViewController()
        namingViewController.delegate = self
        self.viewControllers = [namingViewController]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.barStyle = .blackTranslucent
        view.backgroundColor = .clear
        view.blur(style: .dark)
    }

    private var name: String = ""

    private func showErrorAlert(error: Error? = nil, completion: (() -> ())?) {
        var title = error?.localizedDescription ?? "Unknown error."
        var message = ""

        title = title.replacingOccurrences(of: "CPLResourceTypeOriginal", with: "image")

        if let error = error as NSError?, let underlyingReason = (error.userInfo["NSUnderlyingError"] as? NSError)?.localizedDescription {
            message = underlyingReason
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
            alert.dismiss(animated: true)
            completion?()
        }))

        self.present(alert, animated: true)
    }

    private func finishImport(of assets: [PHAsset], completionHandler: (() -> ())?) {
        let alertView = UIAlertController(title: "Delete assets?", message: "Do you want to keep the raw images in the Photos app?", preferredStyle: .alert)

        alertView.addAction(UIAlertAction(title: "Keep", style: .cancel, handler: { _ in
            completionHandler?()
        }))

        alertView.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            do {
                try PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetChangeRequest.deleteAssets(NSArray(array: assets))
                }
            } catch {
                fatalError("Failed to delete images! \(error.localizedDescription)")
            }

            completionHandler?()
        }))

        present(alertView, animated: true)
    }
}

extension CreateNavigationController: NamingViewControllerDelegate {
    func namingViewControllerDidCancelImport(_ namingViewController: NamingViewController) {
        self.dismiss(animated: true) {
            self.importHandler(nil, .none)
        }
    }

    func namingViewController(_ namingViewController: NamingViewController, didSet name: String) {
        self.name = name

        let selectionVC = ImportSelectionViewController(importManager: importManager)
        selectionVC.delegate = self
        pushViewController(selectionVC, animated: true)
    }
}

extension CreateNavigationController: ImportSelectionViewControllerDelegate {
    func createViewController(_ createViewController: ImportSelectionViewController, didImport assets: [PHAsset]) {
        let progressVC = ImportProgressViewController(importManager: importManager)
        progressVC.totalBytes = importManager.accumulatedFileSize(for: assets)
        pushViewController(progressVC, animated: true)

        let cacheDirectory = UIApplication.documentCreationCacheDirectory()
        let newDocumentURL = cacheDirectory.appendingPathComponent("\(name).photoflow")

        let failureHandler = { (error: Error?) -> Void in
            self.showErrorAlert(error: error) {
                self.dismiss(animated: true) {
                    self.importHandler(nil, .none)
                }
            }
        }

        UIApplication.clearCaches()

        let document = ProjectDocument(fileURL: newDocumentURL, importManager: importManager)

        document.save(to: newDocumentURL, for: .forCreating) { saved in
            guard saved else {
                return failureHandler(DocumentCreationError.unableToSave)
            }

            document.open { opened in
                guard opened else {
                    return failureHandler(DocumentCreationError.unableToOpen)
                }

                // TODO This is potentially destructive. Some images are not being inserted which yields data loss when deleting the images along the way.
                let (producer, progress) = document.importPhotos(from: assets)

                progress.signal.observe(on: QueueScheduler.main).observeValues {
                    progressVC.progress = Float($0)
                }

                let disposable = producer.observe(on: QueueScheduler.main).on(completed: {
                    document.close { closed in
                        guard closed else {
                            return failureHandler(DocumentCreationError.unableToClose)
                        }

                        self.finishImport(of: assets) {
                            self.dismiss(animated: true) {
                                self.importHandler(newDocumentURL, .move)
                            }
                        }
                    }
                }).observe(on: QueueScheduler.main).startWithResult { result in
                    switch result {
                    case .success(let value):
                        progressVC.load(imageData: value)
                    case .failure(let error):
                        failureHandler(error)
                    }
                }

                progressVC.onCancel = {
                    disposable.dispose()
                    self.dismiss(animated: true) {
                        self.importHandler(nil, .none)
                    }
                }
            }
        }
    }
}
