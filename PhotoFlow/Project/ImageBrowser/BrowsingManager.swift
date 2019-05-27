//
//  BrowsingManager.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 26.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

protocol BrowsingManagerFilter {
    func match(image: ImageEntity) -> Bool
}

struct ImageStatusFilter: OptionSet, BrowsingManagerFilter {
    let rawValue: Int

    static let unspecified = ImageStatusFilter(rawValue: 1 << 0)
    static let accepted    = ImageStatusFilter(rawValue: 1 << 1)
    static let rejected    = ImageStatusFilter(rawValue: 1 << 2)

    static let `default`: ImageStatusFilter = [.unspecified, .accepted]
    static let all: ImageStatusFilter = [.unspecified, .accepted, .rejected]

    func match(image: ImageEntity) -> Bool {
        switch image.status {
        case .unspecified:
            return self.contains(.unspecified)
        case .accepted:
            return self.contains(.accepted)
        case .rejected:
            return self.contains(.rejected)
        }
    }
}

protocol BrowsingManagerDelegate: class {
    func browsingManager(_ browsingManager: BrowsingManager, didLoadImageListEntries: [ImageListEntry])
    func browsingManager(_ browsingManager: BrowsingManager, didChangeItemWithIndex: Int)
}

class BrowsingManager {
    private let imageManager: ImageManager
    private(set) var currentList: [ImageEntity.ID] = []

    var filters: [BrowsingManagerFilter]
    weak var delegate: BrowsingManagerDelegate?

    var count: Int {
        return currentList.count
    }

    init(imageManager: ImageManager, initialFilters: [BrowsingManagerFilter] = [ImageStatusFilter.default]) {
        self.filters = initialFilters
        self.imageManager = imageManager
    }

    func loadImages() {
        DispatchQueue.main.async {
            var entities = self.imageManager.imageEntities()

            for filter in self.filters {
                entities = entities.filter { filter.match(image: $0) }
            }

            self.currentList = entities.map { $0.objectID }

            self.delegate?.browsingManager(self, didLoadImageListEntries: self.currentList.map { .image(id: $0) })
        }
    }

    func setStatusOfItem(atIndex index: Int, to status: ImageStatus, resetIfSame: Bool = false) {
        DispatchQueue.main.async {
            if let entity = self.imageManager.imageEntity(withID: self.currentList[index]) {
                if entity.status == status && resetIfSame {
                    entity.status = .unspecified
                } else {
                    entity.status = status
                }
                self.delegate?.browsingManager(self, didChangeItemWithIndex: index)
            }
        }
    }

    subscript(index: Int) -> ImageListEntry {
        get {
            return .image(id: currentList[index])
        }
    }
}
