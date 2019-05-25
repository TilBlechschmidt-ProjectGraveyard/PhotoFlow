//
//  ImageOrientation.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
//import CoreGraphics

extension UIImage.Orientation {
    init?(fromExif orientation: Int) {
        self.init(rawValue: orientation - 1)
    }
}

//struct ImageOrientation: ExpressibleByIntegerLiteral {
//    typealias IntegerLiteralType = Int
//
//    let rotation: CGFloat
//    let flipped: Bool
//
//    init(integerLiteral value: ImageOrientation.IntegerLiteralType) {
//        switch value {
//        case 1:
//            rotation = 0
//            flipped = false
//        case 2:
//            rotation = 0
//            flipped = true
//        case 3:
//            rotation = CGFloat.pi
//            flipped = false
//        case 4:
//            rotation = CGFloat.pi
//            flipped = true
//        case 5:
//            rotation = -CGFloat.pi / 2
//            flipped = true
//        case 6:
//            rotation = -CGFloat.pi / 2
//            flipped = false
//        case 7:
//            rotation = CGFloat.pi / 2
//            flipped = true
//        case 8:
//            rotation = CGFloat.pi / 2
//            flipped = false
//        default:
//            rotation = 0
//            flipped = true
//        }
//    }
//}
