//
//  ImageHasher.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 20.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import CocoaImageHashing

struct ImageHash {
    private static let hasher = OSImageHashing()

    let rawValue: Int64

    init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    init(from image: UIImage) {
        rawValue = autoreleasepool {
            Int64(ImageHash.hasher.hashImage(image, with: .pHash))
        }
    }

    func isSimilar(to other: ImageHash) -> Bool {
//        let threshold = ImageHash.hasher.hashDistanceSimilarityThreshold(withProvider: .pHash)
        let threshold = 20
        return distance(to: other) < threshold
    }

    func distance(to other: ImageHash) -> Int64 {
        return ImageHash.hasher.hashDistance(self.rawValue, to: other.rawValue)
    }
}
