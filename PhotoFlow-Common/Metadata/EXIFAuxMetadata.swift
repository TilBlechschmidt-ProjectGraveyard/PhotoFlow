//
//  EXIFAuxMetadata.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

struct EXIFAuxMetadata {
    let lensModel: String?
    let lensSerialNumber: String?

    let stabilized: Bool

    init(from dict: [String: Any]) {
        // TODO LensModel is sometimes in {Exif} instead of {ExifAux}
        lensModel = dict.take(from: "LensModel")
        lensSerialNumber = dict.take(from: "LensSerialNumber")
        stabilized = dict.take(from: "ImageStabilization") ?? false
    }
}
