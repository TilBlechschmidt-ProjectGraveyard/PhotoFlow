//
//  ShareManager.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 31.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import CoreData
import CoreServices

struct SharingMetadata: Codable {
    let imageEntityID: URL
    let projectBookmark: Data
}

class ShareManager {
    static let temporaryStorageDirectoryName: String = "temporaryShareStorage"
    static let shareMetadataDirectoryName: String = "metadataShareStorage"

    let fileManager = FileManager.default
    let appGroupIdentifier = "group.de.blechschmidt.PhotoFlow"

    func generateOutgoingFilename(forProjectAt location: URL, imageID: NSManagedObjectID) -> String? {
        do {
            let persistentEntityID = imageID.uriRepresentation()
            let projectBookmark = try location.bookmarkData()
            let uid = UUID()

            let metadata = SharingMetadata(imageEntityID: persistentEntityID, projectBookmark: projectBookmark)
            let encoder = JSONEncoder()
            let data = try encoder.encode(metadata)

            guard let appGroupDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
                return nil
            }

            let metadataDirectory = appGroupDirectory.appendingPathComponent(ShareManager.shareMetadataDirectoryName)
            try fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true, attributes: nil)

            let fileURL = metadataDirectory.appendingPathComponent(uid.uuidString)
            try data.write(to: fileURL)

            return uid.uuidString
        } catch {
            // TODO Return a reasonable error
            return nil
        }
    }

    func metadata(for uuidString: String) -> SharingMetadata? {
        guard let appGroupDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }

        let metadataDirectory = appGroupDirectory.appendingPathComponent(ShareManager.shareMetadataDirectoryName)
        let fileURL = metadataDirectory.appendingPathComponent(uuidString)

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let metadata = try decoder.decode(SharingMetadata.self, from: data)

            return metadata
        } catch {
            return nil
        }
    }

    func fileExtension(for uti: String) -> String? {
        return UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() as String?
    }
}
