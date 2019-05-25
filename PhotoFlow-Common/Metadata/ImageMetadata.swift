//
//  ImageMetadata.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 20.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import CoreImage
import CoreGraphics
import CoreLocation

struct ImageMetadata {
    let dimensions: CGSize?
    let orientation: UIImage.Orientation?

    let tiff: TIFFMetadata?
    let exif: EXIFMetadata?
    let aux: EXIFAuxMetadata?

    let location: CLLocationCoordinate2D?

    init(from image: CIImage) {
        let dict = image.properties

        orientation = dict.take(from: "Orientation").flatMap { UIImage.Orientation(fromExif: $0) }
        tiff = dict.take(from: "{TIFF}").flatMap { TIFFMetadata(from: $0) }
        exif = dict.take(from: "{Exif}").flatMap { EXIFMetadata(from: $0) }
        aux = dict.take(from: "{ExifAux}").flatMap { EXIFAuxMetadata(from: $0) }
        location = dict.take(from: "{GPS}").flatMap { CLLocationCoordinate2D(from: $0) }

        if let width: Int = dict.take(from: "PixelWidth"), let height: Int = dict.take(from: "PixelHeight") {
            dimensions = CGSize(width: width, height: height)
        } else {
            dimensions = nil
        }
    }
}

#if os(iOS)
import UIKit

extension ImageMetadata {
    init?(from image: UIImage) {
        guard let ciImage = image.ciImage ?? CIImage(image: image) else {
            return nil
        }

        self.init(from: ciImage)
    }
}
#endif
