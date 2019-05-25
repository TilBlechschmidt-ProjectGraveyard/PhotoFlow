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

        view.backgroundColor = .clear
        view.blur(style: .light)
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

        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            UIApplication.clearCaches()
        } catch {
            return failureHandler(DocumentCreationError.unableToSave)
        }

        let document = ProjectDocument(fileURL: newDocumentURL, importManager: importManager)

        document.save(to: newDocumentURL, for: .forCreating) { saved in
            guard saved else {
                return failureHandler(DocumentCreationError.unableToSave)
            }

            document.open { opened in
                guard opened else {
                    return failureHandler(DocumentCreationError.unableToOpen)
                }

                let (producer, progress) = document.importPhotos(from: assets)

                progress.signal.observe(on: QueueScheduler.main).observeValues {
                    progressVC.progress = Float($0)
                }

                let disposable = producer.observe(on: QueueScheduler.main).on(completed: {
                    document.close { closed in
                        guard closed else {
                            return failureHandler(DocumentCreationError.unableToClose)
                        }

                        self.dismiss(animated: true) {
                            self.importHandler(newDocumentURL, .move)
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
