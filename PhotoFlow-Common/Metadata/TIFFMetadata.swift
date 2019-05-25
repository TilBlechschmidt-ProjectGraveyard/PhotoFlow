//
//  TIFFMetadata.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

struct TIFFMetadata {
    // Other fields: Compression, DateTime, Orientation
    let copyright: String?

    let make: String?
    let model: String?

    let firmwareVersion: String?

    init(from dict: [String: Any]) {
        copyright = dict.take(from: "Copyright")

        make = dict.take(from: "Make")
        model = dict.take(from: "Model")

        firmwareVersion = dict.take(from: "Software")
    }
}
