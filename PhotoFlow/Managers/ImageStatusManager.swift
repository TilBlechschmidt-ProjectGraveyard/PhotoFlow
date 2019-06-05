//
//  ImageStatusManager.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 01.06.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation
import ReactiveSwift

typealias ImageStatusSignal = Signal<(id: ImportedImageEntity.ID, status: ImageStatus), Never>

class ImageStatusManager {
    let imageManager: ImageManager

    let signal: ImageStatusSignal
    private let observer: ImageStatusSignal.Observer

    init(imageManager: ImageManager) {
        self.imageManager = imageManager
        let (output, input) = ImageStatusSignal.pipe()
        self.signal = output
        self.observer = input
    }

    func flag(image id: ImportedImageEntity.ID, as status: ImageStatus, toggle: Bool = false) {
        DispatchQueue.main.async {
            guard let entity = self.imageManager.imageEntity(withID: id) as? ImportedImageEntity else {
                return
            }

            if entity.status == status && toggle {
                entity.status = .unspecified
            } else {
                entity.status = status
            }

            self.observer.send(value: (id: id, status: status))
        }
    }
}
