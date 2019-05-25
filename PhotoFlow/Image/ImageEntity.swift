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

@objc(ImageEntity)
public class ImageEntity: NSManagedObject {
    typealias ID = NSManagedObjectID

    lazy var size: CGSize = {
        return CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }()

    lazy var imageHash: ImageHash = {
        return ImageHash(rawValue: self.perceptualHash)
    }()
}
