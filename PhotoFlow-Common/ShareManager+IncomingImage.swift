
//
//  ShareManager+IncomingImage.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 01.06.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

extension ShareManager {
    func processIncomingImage(withName filename: String, documentBrowserViewController: DocumentBrowserViewController) {
        guard let appGroupDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }

        let temporaryStorageDirectory = appGroupDirectory.appendingPathComponent(ShareManager.temporaryStorageDirectoryName, isDirectory: true)

        let fileURL = temporaryStorageDirectory.appendingPathComponent(filename)
        let cleanup = {
            try! self.fileManager.removeItem(at: fileURL)
            // TODO Remove metadata file - or should we? Maybe we shouldn't if the user wants to import the image again.
            // Maybe provide an option to clean caches like the metadata.
        }

        guard let metadata = metadata(for: fileURL.deletingPathExtension().lastPathComponent) else {
            cleanup()
            return
        }

        var isStale: Bool = false
        let projectURL = try! URL(resolvingBookmarkData: metadata.projectBookmark, bookmarkDataIsStale: &isStale)

        guard !isStale else {
            cleanup()
            return
        }

        // TODO Show UIActivityView + UILabel for importing the image
        let currentlyOpenedDocument = documentBrowserViewController.currentlyOpenedDocument!
        let projectIsOpen = currentlyOpenedDocument.fileURL.standardized == projectURL.standardized

        guard !projectIsOpen else {
            // TODO Use opened document instead of opening a new one
            cleanup()
            return
        }

        documentBrowserViewController.closeDocuments {
            documentBrowserViewController.revealDocument(at: projectURL, importIfNeeded: false) { documentURL, error in
                if let documentURL = documentURL {
                    let document = ProjectDocument(fileURL: documentURL, importManager: documentBrowserViewController.importManager)

                    document.open { success in
                        guard success else {
                            cleanup()
                            return
                        }

                        // TODO Cleanup should now also contain document.close
                        guard let imageManager = document.imageManager else {
                            cleanup()
                            return
                        }

                        let entityID = imageManager.imageEntityID(from: metadata.imageEntityID)

                        do {
                            try imageManager.importEditedImage(from: fileURL, for: entityID)
                        } catch {
                            cleanup()
                            // TODO Show error to user. If error = .editedImageExists show the possiblity to overwrite it.
                            fatalError(error.localizedDescription)
                        }

                        documentBrowserViewController.present(document: document)
                    }
                } else {
                    cleanup()
                }
            }
        }
    }
}
