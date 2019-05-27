//
//  Document.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 19.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import CoreData
import Photos
import ReactiveSwift

class ProjectDocument: UIManagedDocument {
    private let importManager: ImportManager

    var imageManager: ImageManager!

    /// Only call on main thread
    var projectEntity: ProjectEntity {
        return self.projectEntity(from: managedObjectContext)
    }

    func projectEntity(from context: NSManagedObjectContext) -> ProjectEntity {
        // Attempt to fetch the existing entity
        let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()

        if let entities = try? context.fetch(fetchRequest), let entity = entities.first {
            return entity
        } else {
            let entity = ProjectEntity(entity: ProjectEntity.entity(), insertInto: context)
            entity.openCounter = 41
            try! self.managedObjectContext.save()

            return entity
        }
    }

    var title: String {
        return fileURL.deletingPathExtension().lastPathComponent
    }

    /// Only call on main thread
    var openCounter: Int32 {
        return projectEntity.openCounter
    }

    /// Only call on main thread
    var images: [ImageEntity] {
        let fetchRequest: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
        let sort = NSSortDescriptor(key: #keyPath(ImageEntity.creationDate), ascending: true)
        fetchRequest.sortDescriptors = [sort]
        // TODO Filter images by ProjectEntity. Not really necessary since there is only one but whatever.

        return (try? managedObjectContext.fetch(fetchRequest)) ?? []
    }

    func incrementCounter() {
        projectEntity.openCounter += 1
    }

    init(fileURL url: URL, importManager: ImportManager) {
        self.importManager = importManager
        super.init(fileURL: url)
        self.imageManager = ImageManager(document: self)
    }

    private static var defaultImportOptions: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = PHImageRequestOptionsVersion.original
        return options
    }

    private func thumbnail(for asset: PHAsset) -> SignalProducer<UIImage, Error> {
        return SignalProducer { observer, lifetime in
            let options = ProjectDocument.defaultImportOptions
            options.deliveryMode = .highQualityFormat

            let size = CGSize(width: 500, height: 500)
            let requestID = self.importManager.imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, info in
                if let image = image {
                    observer.send(value: image)
                    observer.sendCompleted()
                } else if let info = info, let error = info[PHImageErrorKey] as? NSError {
                    observer.send(error: error)
                }
            }

            lifetime.observeEnded {
                self.importManager.imageManager.cancelImageRequest(requestID)
            }
        }
    }

    private func originalImage(for asset: PHAsset, with options: PHImageRequestOptions) -> SignalProducer<(Data, String?), Error> {
        return SignalProducer { observer, lifetime in
            let requestID = self.importManager.imageManager.requestImageData(for: asset, options: options) { imageData, dataUTI, orientation, info in
                if let data = imageData {
                    observer.send(value: (data, dataUTI))
                    observer.sendCompleted()
                } else if let info = info, let error = info[PHImageErrorKey] as? NSError {
                    let reason = error.localizedDescription
                    let underlyingReason = (error.userInfo["NSUnderlyingError"] as? NSError)?.localizedDescription
                    print("Unable to read image data. \(reason) - \(underlyingReason ?? "Unknown reason")")
                    observer.send(error: error)
                }
            }

            lifetime.observeEnded {
                self.importManager.imageManager.cancelImageRequest(requestID)
            }
        }
    }

    func importPhoto(from asset: PHAsset, with options: PHImageRequestOptions = ProjectDocument.defaultImportOptions) -> SignalProducer<Data, Error> {

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)

        managedObjectContext.performAndWait {
            context.parent = managedObjectContext
        }

        let originalImageProducer = originalImage(for: asset, with: options)
        let thumbnailProducer = thumbnail(for: asset)

        return SignalProducer.zip(originalImageProducer, thumbnailProducer)
            .map { originalImage, thumbnail in
                let (data, dataUTI) = originalImage

                // TODO Remove force unwrap
                let uiImage = UIImage(data: data)!
                let ciImage = CIImage(data: data)!
                let metadata = ImageMetadata(from: ciImage)
                let creationDate = metadata.exif?.captureTime ?? asset.creationDate ?? Date()
                let originalFilename = self.importManager.originalFileName(for: asset)

                // Store the image
                context.performAndWait {
                    let orientation = metadata.orientation ?? UIImage.Orientation.up
                    let imageHash = ImageHash(from: uiImage)

                    let imageEntity = NSEntityDescription.insertNewObject(forEntityName: "ImageEntity", into: context) as! ImageEntity
                    imageEntity.width = Int32(asset.pixelWidth)
                    imageEntity.height = Int32(asset.pixelHeight)
                    imageEntity.creationDate = creationDate
                    imageEntity.data = data
                    imageEntity.thumbnailData = thumbnail.jpegData(compressionQuality: 0.6)
                    imageEntity.uti = dataUTI
                    imageEntity.originalFilename = originalFilename
                    imageEntity.perceptualHash = imageHash.rawValue
                    imageEntity.orientation = Int16(orientation.rawValue)

                    let projectEntity = self.projectEntity(from: context)
                    projectEntity.addToImages(imageEntity)
                    context.processPendingChanges()
                    try? context.save()
                    self.updateChangeCount(.done)
                }

                return data
            }
    }

    func importPhotos(from assets: [PHAsset]) -> (producer: SignalProducer<Data, Error>, progress: Property<Double>) {
        let options = ProjectDocument.defaultImportOptions

        let perItemProgress = 100.0 / Double(assets.count) / 100.0
        var currentItemProgress = 0.0
        var importedImagesCount = 0.0
        let totalProgress = MutableProperty(0.0)
        let updateProgress = {
            totalProgress.value = importedImagesCount * perItemProgress + currentItemProgress * perItemProgress
        }

        options.progressHandler = { progress, _, _, _ in
            currentItemProgress = progress
            updateProgress()
        }

        let imports = assets.map { asset in
            return self.importPhoto(from: asset, with: options)
                .on(completed: {
                    importedImagesCount += 1
                    currentItemProgress = 0
                    updateProgress()
                })
        }

        return (
            producer: SignalProducer(imports).flatMap(.concurrent(limit: 1)) { $0 },
            progress: Property(capturing: totalProgress)
        )
    }

//    // TODO Deduplicate the code in this and the next function
//    func image(after id: ImageEntity.ID) -> ImageEntity.ID? {
//        guard let entity = imageManager.imageEntity(withID: id), let creationDate = entity.creationDate else {
//            return nil
//        }
//
//        let fetchRequest: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
//        let sort = NSSortDescriptor(key: #keyPath(ImageEntity.creationDate), ascending: true)
//        fetchRequest.sortDescriptors = [sort]
//        fetchRequest.fetchLimit = 1
//        fetchRequest.predicate = NSPredicate(format: "creationDate > %@", NSDate(timeIntervalSince1970: creationDate.timeIntervalSince1970))
//        // TODO Filter images by ProjectEntity. Not really necessary since there is only one but whatever.
//
//        return (try? managedObjectContext.fetch(fetchRequest))?.first?.objectID
//    }
//
//    func image(before id: ImageEntity.ID) -> ImageEntity.ID? {
//        guard let entity = imageManager.imageEntity(withID: id), let creationDate = entity.creationDate else {
//            return nil
//        }
//
//        let fetchRequest: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
//        let sort = NSSortDescriptor(key: #keyPath(ImageEntity.creationDate), ascending: false)
//        fetchRequest.sortDescriptors = [sort]
//        fetchRequest.fetchLimit = 1
//        fetchRequest.predicate = NSPredicate(format: "creationDate < %@", NSDate(timeIntervalSince1970: creationDate.timeIntervalSince1970))
//        // TODO Filter images by ProjectEntity. Not really necessary since there is only one but whatever.
//
//        return (try? managedObjectContext.fetch(fetchRequest))?.first?.objectID
//    }
}
