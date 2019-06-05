//
//  ProjectGridSettings.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 28.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

enum ProjectGridItemLabelType: String {
    case creationTime
    case originalFilename
    case cameraSettings

    static func load() -> ProjectGridItemLabelType {
        let settingsString = ProjectGridSettings.get(setting: .itemLabelContent) as? String
        return settingsString.flatMap { ProjectGridItemLabelType(rawValue: $0) } ?? .originalFilename
    }
}

enum ProjectGridSettings: SettingsKit {
    case itemLabelContent

    var identifier: String {
        switch self {
        case .itemLabelContent:
            return "projectGrid.itemLabelContent"
        }
    }

    static var defaults: [String : Any] = [
        ProjectGridSettings.itemLabelContent.identifier: ProjectGridItemLabelType.originalFilename.rawValue
    ]
}
