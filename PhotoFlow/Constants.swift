//
//  Constants.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import CoreGraphics

struct Constants {
    static let spacing: CGFloat = 10
    static let insets = UIEdgeInsets(top: Constants.spacing, left: Constants.spacing, bottom: Constants.spacing, right: Constants.spacing)
    static let colors = (
        blue: UIColor.init(red: 0.177, green: 0.53, blue: 0.98, alpha: 1.0),
        border: #colorLiteral(red: 0.3726548851, green: 0.3726548851, blue: 0.3726548851, alpha: 1),
        background: #colorLiteral(red: 0.1176470588, green: 0.1176470588, blue: 0.1176470588, alpha: 1),
        lightBackground: #colorLiteral(red: 0.1960784314, green: 0.1960784314, blue: 0.1960784314, alpha: 1),
        darkBackground: #colorLiteral(red: 0.05882352941, green: 0.05882352941, blue: 0.05882352941, alpha: 1),
        accepted: #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1),
        rejected: #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
    )
}
