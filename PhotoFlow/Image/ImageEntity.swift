//
//  ImageEntity.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 23.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import CoreData
import ReactiveSwift
import CoreServices

enum ImageStatus: Int16 {
    case unspecified = 0
    case accepted = 1
    case rejected = 2
}


@objc(ImageEntity)
public class ImageEntity: NSManagedObject {
    typealias ID = NSManagedObjectID

    lazy var size: CGSize = {
        return CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }()

    lazy var humanReadableUTI: String? = {
        return self.uti.flatMap {
            UTTypeCopyDescription($0 as CFString)?.takeRetainedValue() as String?
        }
    }()
}

@objc(ImportedImageEntity)
public class ImportedImageEntity: ImageEntity {
    lazy var imageHash: ImageHash = {
        return ImageHash(rawValue: self.perceptualHash)
    }()

    var status: ImageStatus {
        get {
            return ImageStatus(rawValue: self.statusValue) ?? .unspecified
        }
        set {
            self.statusValue = newValue.rawValue
        }
    }
}
