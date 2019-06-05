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

    private(set) var imageManager: ImageManager!
    private(set) var statusManager: ImageStatusManager!

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
            try! self.managedObjectContext.save()

            return entity
        }
    }

    var title: String {
        return fileURL.deletingPathExtension().lastPathComponent
    }

    /// Only call on main thread
    var images: [ImageEntity] {
        let fetchRequest: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
        let sort = NSSortDescriptor(key: #keyPath(ImageEntity.creationDate), ascending: true)
        fetchRequest.sortDescriptors = [sort]
        // TODO Filter images by ProjectEntity. Not really necessary since there is only one but whatever.

        return (try? managedObjectContext.fetch(fetchRequest)) ?? []
    }

    init(fileURL url: URL, importManager: ImportManager) {
        self.importManager = importManager
        super.init(fileURL: url)
        self.imageManager = ImageManager(document: self)
        self.statusManager = ImageStatusManager(imageManager: imageManager)
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

    func createBackgroundContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)

        managedObjectContext.performAndWait {
            context.parent = managedObjectContext
        }

        return context
    }

    func importPhoto(from asset: PHAsset, with options: PHImageRequestOptions = ProjectDocument.defaultImportOptions) -> SignalProducer<Data, Error> {

        let context = createBackgroundContext()

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

                    let imageEntity = NSEntityDescription.insertNewObject(forEntityName: "ImportedImageEntity", into: context) as! ImportedImageEntity
                    imageEntity.width = Int32(asset.pixelWidth)
                    imageEntity.height = Int32(asset.pixelHeight)
                    imageEntity.creationDate = creationDate
                    imageEntity.data = data
                    imageEntity.thumbnailData = thumbnail.jpegData(compressionQuality: 0.6)
                    imageEntity.uti = dataUTI
                    imageEntity.originalFilename = originalFilename
                    imageEntity.perceptualHash = imageHash.rawValue
                    imageEntity.orientation = Int16(orientation.rawValue)
                    imageEntity.filesize = self.importManager.fileSize(for: asset) ?? 0

//                    let projectEntity = self.projectEntity(from: context)
//                    projectEntity.addToImages(imageEntity)

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

    func importedImageIDs() -> SignalProducer<[ImportedImageEntity.ID], Error> {
        return SignalProducer { observer, _ in
            let context = self.createBackgroundContext()
            context.perform {
                let fetchRequest: NSFetchRequest<ImportedImageEntity> = ImportedImageEntity.fetchRequest()
                let sort = NSSortDescriptor(key: #keyPath(ImportedImageEntity.creationDate), ascending: true)
                fetchRequest.sortDescriptors = [sort]

                // TODO Filter images by ProjectEntity. Not really necessary since there is only one but whatever.

                do {
                    let images = try context.fetch(fetchRequest)
                    observer.send(value: images.map { $0.objectID })
                    observer.sendCompleted()
                } catch {
                    observer.send(error: error)
                    return
                }
            }
        }
    }

    func editedImageIDs() -> SignalProducer<[EditedImageEntity.ID], Error> {
        return SignalProducer { observer, _ in
            let context = self.createBackgroundContext()
            context.perform {
                let fetchRequest: NSFetchRequest<EditedImageEntity> = EditedImageEntity.fetchRequest()
                let sort = NSSortDescriptor(key: #keyPath(EditedImageEntity.creationDate), ascending: true)
                fetchRequest.sortDescriptors = [sort]

                // TODO Filter images by ProjectEntity. Not really necessary since there is only one but whatever.

                do {
                    let images = try context.fetch(fetchRequest)
                    observer.send(value: images.map { $0.objectID })
                    observer.sendCompleted()
                } catch {
                    observer.send(error: error)
                    return
                }
            }
        }
    }
}
