//
//  ImageEntity+EXIF.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 23.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import CoreImage

extension ImageEntity {
    var metadata: ImageMetadata? {
        guard let data = self.data, let image = CIImage(data: data) else {
            return nil
        }
        
        return ImageMetadata(from: image)
    }

    var image: UIImage? {
        guard let data = self.data else {
            return nil
        }

        return UIImage(data: data)
    }
}
