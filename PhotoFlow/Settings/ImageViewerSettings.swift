//
//  ImageViewerSettings.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 28.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

enum SettingsHistogramType: String {
    case luminance
    case rgb

    static func load() -> SettingsHistogramType {
        let settingsString = ImageViewerSettings.get(setting: .defaultHistogramType) as? String
        return settingsString.flatMap { SettingsHistogramType(rawValue: $0) } ?? .rgb
    }
}

enum ImageViewerSettings: SettingsKit {
    case infoPanelShown
    case defaultHistogramType
    case nextOnFlag

    var identifier: String {
        switch self {
        case .infoPanelShown:
            return "imageViewer.infoPanelVisible"
        case .defaultHistogramType:
            return "imageViewer.defaultHistogramType"
        case .nextOnFlag:
            return "imageViewer.nextOnFlag"
        }
    }

    static var defaults: [String : Any] = [
        ImageViewerSettings.infoPanelShown.identifier: true,
        ImageViewerSettings.defaultHistogramType.identifier: SettingsHistogramType.rgb.rawValue,
        ImageViewerSettings.nextOnFlag.identifier: false
    ]
}
