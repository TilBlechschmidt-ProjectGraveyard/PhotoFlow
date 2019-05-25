//
//  main.swift
//  PhotoFlow-Mac
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import CoreImage

let image = CIImage(contentsOf: URL(fileURLWithPath: "/Users/themegatb/Downloads/Untitled (1).heic"))! // _MG_4086.CR2, _1060031.RW2
let meta = ImageMetadata(from: image)

print(meta.exif!.captureTime!)
print()
print(meta.tiff!.make!)
print(meta.tiff!.model!)
print(meta.tiff!.firmwareVersion)
print()
print(meta.aux?.lensModel)

print(meta.location)
