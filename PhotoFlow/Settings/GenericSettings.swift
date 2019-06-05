//
//  SettingsManager.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 28.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

enum GenericSettings: SettingsKit {
    case appVersion

    var identifier: String {
        switch self {
        case .appVersion:
            return "appVersion"
        }
    }

    static var defaults: [String : Any] = [:]
}
