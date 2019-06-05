//
//  BrowsingManager.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 26.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

protocol BrowsingManagerFilter {
    func match(id: ImageEntity.ID, imageManager: ImageManager) -> Bool
}

enum BrowsingManagerChangeSetEntry {
    case insert(at: Int)
    case remove(at: Int)
    case update(at: Int)
}

typealias BrowsingManagerChangeSet = [BrowsingManagerChangeSetEntry]

protocol BrowsingManagerDelegate: class {
    func browsingManager(_ browsingManager: BrowsingManager, didFilterItems changeSet: BrowsingManagerChangeSet)
    func browsingManager(_ browsingManager: BrowsingManager, didUpdateItem at: Int)
    func browsingManagerDidExchangeItems(_ browsingManager: BrowsingManager)
}

class BrowsingManager {
    private let managerID = UUID()

    private let imageManager: ImageManager
    private let statusManager: ImageStatusManager

    private var filteredImages: [ImageEntity.ID]
    private var filterResults: [Bool]

    var images: [ImageEntity.ID] { didSet { imagesChanged() } }
    var filters: [BrowsingManagerFilter] { didSet { applyFilters() } }
    weak var delegate: BrowsingManagerDelegate?

    init(imageManager: ImageManager, statusManager: ImageStatusManager, images: [ImageEntity.ID] = [], filters: [BrowsingManagerFilter] = [ImageStatusFilter.all]) {
        self.imageManager = imageManager
        self.statusManager = statusManager

        self.images = images
        self.filteredImages = images
        self.filterResults = Array(repeating: true, count: images.count)
        self.filters = filters

        applyFilters()

        statusManager.signal.take(duringLifetimeOf: self).observeValues { [unowned self] value in
            let (id, _) = value
            if let changedIndex = self.filteredImages.firstIndex(of: id) {
                self.delegate?.browsingManager(self, didUpdateItem: changedIndex)
            }
        }
    }

    func createCopy() -> BrowsingManager {
        return BrowsingManager(imageManager: imageManager, statusManager: statusManager, images: images, filters: filters)
    }

    private func imagesChanged() {
        filterResults = Array(repeating: true, count: images.count)
        applyFilters(tellDelegate: false)
        delegate?.browsingManagerDidExchangeItems(self)
    }

    private func applyFilters(tellDelegate: Bool = true) {
        var changeSet: BrowsingManagerChangeSet = []
        var filteredImages: [ImageEntity.ID] = []

        let previousFilterResults = filterResults

        for i in images.indices {
            let imageID = images[i]
            let previousFilterResult = filterResults[i]
            let newFilterResult = applyFilters(on: imageID)

            filterResults[i] = newFilterResult

            if newFilterResult {
                filteredImages.append(imageID)
            }

            // Since the output list doesn't contain all the elements in index i is offset by the number of zeros in filterResult.
            // Thus we need to calculate a corrected index that points to the index in filteredImages.
            if previousFilterResult && !newFilterResult {
                let correctedIndex = previousFilterResults[..<i].reduce(0) { $0 + ($1 ? 1 : 0) }
                changeSet.append(.remove(at: correctedIndex))
            } else if !previousFilterResult && newFilterResult {
                let correctedIndex = filterResults[..<i].reduce(0) { $0 + ($1 ? 1 : 0) }
                changeSet.append(.insert(at: correctedIndex))
            }
        }

        self.filteredImages = filteredImages

        if tellDelegate {
            delegate?.browsingManager(self, didFilterItems: changeSet)
        }
    }

    private func applyFilters(on id: ImageEntity.ID) -> Bool {
        return filters.reduce(true) { result, filter in
            return result && filter.match(id: id, imageManager: self.imageManager)
        }
    }
}

extension BrowsingManager {
    var count: Int {
        return filteredImages.count
    }

    func index(after index: Int) -> Int? {
        return filteredImages.index(from: index, offset: 1)
    }

    func index(before index: Int) -> Int? {
        return filteredImages.index(from: index, offset: -1)
    }

    subscript(index: Int) -> ImageEntity.ID {
        get {
            return filteredImages[index]
        }
    }
}

extension BrowsingManager: Equatable {
    static func == (lhs: BrowsingManager, rhs: BrowsingManager) -> Bool {
        return lhs.managerID == rhs.managerID
    }
}

struct ImageStatusFilter: OptionSet, BrowsingManagerFilter {
    let rawValue: Int

    static let unspecified = ImageStatusFilter(rawValue: 1 << 0)
    static let accepted    = ImageStatusFilter(rawValue: 1 << 1)
    static let rejected    = ImageStatusFilter(rawValue: 1 << 2)

    static let `default`: ImageStatusFilter = [.unspecified, .accepted]
    static let all: ImageStatusFilter = [.unspecified, .accepted, .rejected]

    func match(id: ImageEntity.ID, imageManager: ImageManager) -> Bool {
        guard let entity = imageManager.imageEntity(withID: id) as? ImportedImageEntity else {
            return true
        }

        switch entity.status {
        case .unspecified:
            return self.contains(.unspecified)
        case .accepted:
            return self.contains(.accepted)
        case .rejected:
            return self.contains(.rejected)
        }
    }
}

//protocol BrowsingManagerDelegate: class {
//    func browsingManager(_ browsingManager: BrowsingManager, didLoadImageListEntries: [ImageListEntry])
//    func browsingManager(_ browsingManager: BrowsingManager, didChangeItemWithIndex: Int)
//}
//
//class BrowsingManager {
//    let imageManager: ImageManager
//
//    private(set) var importedList: [ImageEntity.ID] = []
//    private(set) var editedList: [ImageEntity.ID] = []
//
//    var filters: [BrowsingManagerFilter]
//    // TODO Figure out how to not make this a strong reference
//    var delegates: [String: BrowsingManagerDelegate] = [:]
//
//    var count: Int {
//        return currentList.count
//    }
//
//    init(imageManager: ImageManager, initialFilters: [BrowsingManagerFilter] = [ImageStatusFilter.default]) {
//        self.filters = initialFilters
//        self.imageManager = imageManager
//    }
//
//    func loadImages() {
//        DispatchQueue.main.async {
//            var entities = self.imageManager.imageEntities()
//
//            for filter in self.filters {
//                entities = entities.filter { filter.match(image: $0) }
//            }
//
//            self.currentList = entities.map { $0.objectID }
//
//            self.delegates.values.forEach {
//                $0.browsingManager(self, didLoadImageListEntries: self.currentList.map { .image(id: $0) })
//            }
//        }
//    }
//
//    func setStatusOfItem(at index: Int, to status: ImageStatus, resetIfSame: Bool = false) {
//        DispatchQueue.main.async {
//            if let entity = self.imageManager.imageEntity(withID: self.currentList[index]) as? ImportedImageEntity {
//                if entity.status == status && resetIfSame {
//                    entity.status = .unspecified
//                } else {
//                    entity.status = status
//                }
//
//                self.delegates.values.forEach {
//                    $0.browsingManager(self, didChangeItemWithIndex: index)
//                }
//            }
//        }
//    }
//
//    func entityID(at index: Int) -> ImageEntity.ID {
//        return currentList[index]
//    }
//
//    /// ImageEntity for given index. Main thread only!
//    func entity(at index: Int) -> ImageEntity? {
//        return imageManager.imageEntity(withID: entityID(at: index))
//    }
//
//    func index(after index: Int) -> Int? {
//        return currentList.index(from: index, offset: 1)
//    }
//
//    func index(before index: Int) -> Int? {
//        return currentList.index(from: index, offset: -1)
//    }
//
//    subscript(index: Int) -> ImageListEntry {
//        get {
//            return .image(id: currentList[index])
//        }
//    }
//}
