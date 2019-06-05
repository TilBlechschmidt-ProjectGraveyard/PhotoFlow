//
//  ShareViewController.swift
//  PhotoFlow-ShareExtension
//
//  Created by Til Blechschmidt on 31.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import MobileCoreServices
import WebKit

@objc(ShareViewController)
class ShareViewController: UIViewController {
    private let shareManager = ShareManager()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.global().async {
            self.imageURLFromExtensionContext() { url in
                if let url = url {
                    let filename = url.lastPathComponent
                    guard self.shareManager.metadata(for: url.deletingPathExtension().lastPathComponent) != nil else {
                        self.showAlert(title: "Unknown image", message: "The image couldn't be identified. Note that you shouldn't change its filename in the editing process!")
                        return
                    }

                    guard self.storeImage(from: url) else {
                        self.showAlert(title: "Error storing image", message: "Unable to store image on disk.")
                        return
                    }

                    self.openParentApp(withImageFilename: filename)
                } else {
                    self.showAlert(title: "Error loading image", message: "Unable to receive image from share panel.")
                }
            }
        }
    }

    func storeImage(from source: URL) -> Bool {
        let appGroupIdentifier = "group.de.blechschmidt.PhotoFlow"
        let fileManager = FileManager.default

        guard let appGroupDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return false
        }

        let temporaryStorageDirectory = appGroupDirectory.appendingPathComponent("temporaryShareStorage", isDirectory: true)
        let destination = temporaryStorageDirectory.appendingPathComponent(source.lastPathComponent)

        do {
            try fileManager.createDirectory(at: temporaryStorageDirectory, withIntermediateDirectories: true, attributes: nil)

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            try fileManager.copyItem(at: source, to: destination)
        } catch {
            return false
        }

        return true
    }

    func imageURLFromExtensionContext(completionHandler: @escaping (URL?) -> ()) {
        for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
            for provider in item.attachments! {
                if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil, completionHandler: { (imageURL, error) in
                        if let imageURL = imageURL as? URL {
                            completionHandler(imageURL)
                        } else {
                            completionHandler(nil)
                        }
                    })
                    break
                }
            }
        }
    }

    func openParentApp(withImageFilename: String) {
        var responder = self as UIResponder?
        let url = URL(string: "photoflow://continueWorkflow/\(withImageFilename)")!

        while (responder != nil) {
            if let application = responder as? UIApplication {
                DispatchQueue.global().async {
//                    application.open(url, options: [:]) { success in
//                        if !success {
//                            self.showAlert(title: "Error importing image", message: "Unable to redirect to parent app.")
//                        }
//                    }
                }

                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                self.dismiss(animated: false, completion: nil)

                return
            }

            responder = responder!.next
        }

        showAlert(title: "Error importing image", message: "Unable to find parent app.")
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { _ in
            alert.dismiss(animated: true)
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }))

        present(alert, animated: true)
    }
}
