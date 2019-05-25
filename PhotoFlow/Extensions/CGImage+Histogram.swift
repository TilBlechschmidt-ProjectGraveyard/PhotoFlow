//
//  CGImage+Histogram.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 24.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import CoreGraphics
import Accelerate

extension CGImage {
    func calculateHistogram() -> (alpha: [UInt], red: [UInt], green: [UInt], blue: [UInt]) {
        var inBuffer = vImage_Buffer()

        var format = vImage_CGImageFormat(bitsPerComponent: 8,
                                          bitsPerPixel: 32,
                                          colorSpace: nil,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                          version: 0,
                                          decode: nil,
                                          renderingIntent: .defaultIntent)

        let bufferError = vImageBuffer_InitWithCGImage(&inBuffer, &format, nil, self, vImage_Flags(kvImageNoFlags))

        guard bufferError == kvImageNoError else {
            fatalError("Buffer error.")
        }

        let alpha = [UInt](repeating: 0, count: 256)
        let red = [UInt](repeating: 0, count: 256)
        let green = [UInt](repeating: 0, count: 256)
        let blue = [UInt](repeating: 0, count: 256)

        let alphaPtr = UnsafeMutablePointer<vImagePixelCount>(mutating: alpha) as UnsafeMutablePointer<vImagePixelCount>?
        let redPtr = UnsafeMutablePointer<vImagePixelCount>(mutating: red) as UnsafeMutablePointer<vImagePixelCount>?
        let greenPtr = UnsafeMutablePointer<vImagePixelCount>(mutating: green) as UnsafeMutablePointer<vImagePixelCount>?
        let bluePtr = UnsafeMutablePointer<vImagePixelCount>(mutating: blue) as UnsafeMutablePointer<vImagePixelCount>?

        let rgba = [redPtr, greenPtr, bluePtr, alphaPtr]

        let histogram = UnsafeMutablePointer<UnsafeMutablePointer<vImagePixelCount>?>(mutating: rgba)
        let histogramError = vImageHistogramCalculation_ARGB8888(&inBuffer, histogram, UInt32(kvImageNoFlags))

        guard histogramError == kvImageNoError else {
            fatalError("Histogram error.")
        }

        print(red)
        print()
        print(green)
        print()
        print(blue)

        return (alpha: alpha, red: red, green: green, blue: blue)
    }
}
