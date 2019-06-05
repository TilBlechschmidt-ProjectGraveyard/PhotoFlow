//
//  ImageManager.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 23.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import CoreData
import ReactiveSwift

struct ImageType: OptionSet {
    let rawValue: Int

    static let imported = ImageType(rawValue: 1 << 0)
    static let edited   = ImageType(rawValue: 1 << 1)

    static let all: ImageType = [.imported, .edited]
}

enum ImageListEntry {
    case image(id: ImageEntity.ID)
    case group(withContents: [ImageListEntry])
}

enum ImageFetchMode {
    case thumbnail
    case original
    case opportunistic
}

enum ImageManagerError: Error {
    case imageNotFound
    case unableToReadImage
    case editedImageExists
}

class ImageManager {
    private let document: ProjectDocument
    private let queueScheduler = QueueScheduler.init(qos: .utility, name: "ImageEntity rendering", targeting: nil)

    init(document: ProjectDocument) {
        self.document = document
    }

    var projectLocation: URL {
        return document.fileURL
    }

    func imageIDs(for type: ImageType) -> SignalProducer<[ImageEntity.ID], Error> {
        var producers: [SignalProducer<[ImageEntity.ID], Error>] = []

        if type.contains(.edited) {
            producers.append(document.editedImageIDs())
        }

        if type.contains(.imported) {
            producers.append(document.importedImageIDs())
        }

        return SignalProducer(producers)
            .flatten(.merge)
            .flatten()
            .collect()
    }
    
//    /// Main thread only!
//    func imageEntities() -> [ImageEntity] {
//        return document.images
//    }
//
//    func imageEntityIDs() -> [ImageEntity.ID] {
//        var imageEntityIDs: [ImageEntity.ID] = []
//        DispatchQueue.main.sync {
//            imageEntityIDs = document.images.map { $0.objectID }
//        }
//        return imageEntityIDs
//    }
//
//    func imageList() -> [ImageListEntry] {
//        let entities = self.document.images
//
//        // TODO IMAGE REFACTORING
//        return entities.map { .image(id: $0.objectID) }
////        guard let firstItem = entities.first else {
////            return []
////        }
////
////        var currentGroupHashes: [ImageHash] = [firstItem.imageHash]
////        var currentGroup: [ImageListEntry] = [.image(id: firstItem.objectID)]
////        var results: [ImageListEntry] = []
////
////        let pushCurrentGroup = {
////            results.append(
////                currentGroup.count > 1 ? .group(withContents: currentGroup) : currentGroup[0]
////            )
////            currentGroupHashes = []
////            currentGroup = []
////        }
////
////        for entity in entities[1...] {
////            let isSimilarToCurrentGroup = currentGroupHashes.reduce(false) { $0 || entity.imageHash.isSimilar(to: $1) }
////
////            if !isSimilarToCurrentGroup {
////                pushCurrentGroup()
////            }
////
////            currentGroup.append(.image(id: entity.objectID))
////            currentGroupHashes.append(entity.imageHash)
////        }
////
////        pushCurrentGroup()
////
////        return results
//    }

    /// Attempts to fetch an image from the document. Only execute on the main thread!
    ///
    /// - Parameter id: Internal core data object id.
    /// - Returns: Fetched image. nil if id is invalid.
    func imageEntity(withID id: ImageEntity.ID) -> ImageEntity? {
        return document.managedObjectContext.object(with: id) as? ImageEntity
    }

    func imageEntityID(from url: URL) -> ImageEntity.ID? {
        return document.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
    }

    func fetchImageData(ofImageWithID id: ImageEntity.ID, thumbnail: Bool = false) -> SignalProducer<Data, Error> {
        let fetchContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        fetchContext.parent = document.managedObjectContext

        return SignalProducer { observer, _ in
            fetchContext.perform {
                guard let imageEntity = fetchContext.object(with: id) as? ImageEntity else {
                    observer.send(error: ImageManagerError.imageNotFound)
                    return
                }

                let optionalData = thumbnail ? imageEntity.thumbnailData : imageEntity.data
                guard let data = optionalData else {
                    observer.send(error: ImageManagerError.unableToReadImage)
                    return
                }

                observer.send(value: data)
                observer.sendCompleted()
            }
        }.observe(on: queueScheduler)
    }

    func fetchMetadata(ofImageWithID id: ImageEntity.ID) -> SignalProducer<ImageMetadata, Error> {
        return fetchImageData(ofImageWithID: id).attemptMap { data in
            guard let image = CIImage(data: data) else {
                throw ImageManagerError.unableToReadImage
            }

            return ImageMetadata(from: image)
        }
    }

    private func fetchImage(withID id: ImageEntity.ID, thumbnail: Bool = false) -> SignalProducer<UIImage, Error> {
        return fetchImageData(ofImageWithID: id, thumbnail: thumbnail).attemptMap { data in
            guard let image = UIImage(data: data) else {
                throw ImageManagerError.unableToReadImage
            }

            return image
        }
    }

    private func opportunisticallyFetchImage(withID id: ImageEntity.ID) -> SignalProducer<UIImage, Error> {
        let thumbnailFetch = fetchImageData(ofImageWithID: id, thumbnail: true)
        let fullQualityFetch = fetchImageData(ofImageWithID: id, thumbnail: false)

        return thumbnailFetch.concat(fullQualityFetch).attemptMap { data in
            guard let image = UIImage(data: data) else {
                throw ImageManagerError.unableToReadImage
            }

            return image
        }
    }

    func fetchImage(withID id: ImageEntity.ID, mode: ImageFetchMode = .thumbnail) -> SignalProducer<UIImage, Error> {
        switch mode {
        case .thumbnail:
            return fetchImage(withID: id, thumbnail: true)
        case .original:
            return fetchImage(withID: id, thumbnail: false)
        case .opportunistic:
            return opportunisticallyFetchImage(withID: id)
        }
    }

    func importEditedImage(from url: URL, for entityID: ImageEntity.ID?, overwrite: Bool = false) throws {
        let data = try Data(contentsOf: url)
        let sourceEntity = entityID.flatMap { self.imageEntity(withID: $0) }

        guard let image = UIImage(data: data) else {
            throw ImageManagerError.unableToReadImage
        }

        let imageEntity = NSEntityDescription.insertNewObject(forEntityName: "EditedImageEntity", into: document.managedObjectContext) as! EditedImageEntity
        imageEntity.orientation = sourceEntity?.orientation ?? Int16(UIImage.Orientation.up.rawValue)
        imageEntity.width = Int32(ceil(image.size.width))
        imageEntity.height = Int32(ceil(image.size.height))
        imageEntity.filesize = Int64(data.count)
        imageEntity.originalFilename = sourceEntity?.originalFilename ?? "Edited Image"
        imageEntity.uti = url.typeIdentifier
        imageEntity.creationDate = Date()
        imageEntity.data = data
        imageEntity.thumbnailData = generateThumbnail(for: url)

        try document.managedObjectContext.save()
    }

    private func generateThumbnail(for url: URL) -> Data? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let scale = UIScreen.main.scale
        let maximumDimension = 500 * scale
        let options: [NSObject: AnyObject] = [
            kCGImageSourceShouldAllowFloat : true as CFBoolean,
            kCGImageSourceCreateThumbnailWithTransform : true as CFBoolean,
            kCGImageSourceCreateThumbnailFromImageAlways : true as CFBoolean,
            kCGImageSourceThumbnailMaxPixelSize : maximumDimension as CFNumber
        ]

        guard let imref = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return nil
        }

        let thumbnail = UIImage(cgImage: imref, scale: scale, orientation: .up)
        let data = thumbnail.pngData()

        return data
    }
}
