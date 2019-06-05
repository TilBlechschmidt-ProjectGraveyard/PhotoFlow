//
//  main.swift
//  PhotoFlow-Mac
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Cocoa
import CoreImage
import ImageIO

let url1 = URL(fileURLWithPath: "/Users/themegatb/Downloads/../Projects/")
let url2 = URL(fileURLWithPath: "/Users/themegatb/Projects/")
print(url1.path, url1.standardized.path, url1.standardized == url2)

//let url = URL(fileURLWithPath: "/Users/themegatb/Downloads/TestFile.CR2")
//let cgImage = NSImage(contentsOf: url)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
//let start = Date()
//let histogram = cgImage.calculateNormalizedHistogram()
//
//print(Date().timeIntervalSince(start))
//print(histogram)

//let image = CIImage(contentsOf: URL(fileURLWithPath: "/Users/themegatb/Downloads/Untitled (1).heic"))! // _MG_4086.CR2, _1060031.RW2
//let meta = ImageMetadata(from: image)
//
//print(meta.exif!.captureTime!)
//print()
//print(meta.tiff!.make!)
//print(meta.tiff!.model!)
//print(meta.tiff!.firmwareVersion)
//print()
//print(meta.aux?.lensModel)
//
//print(meta.location)
