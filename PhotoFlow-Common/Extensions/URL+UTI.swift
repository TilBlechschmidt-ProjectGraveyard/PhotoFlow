//
//  URL+UTI.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 01.06.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

extension URL {
    var typeIdentifier: String? {
        return (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
    }
    var localizedName: String? {
        return (try? resourceValues(forKeys: [.localizedNameKey]))?.localizedName
    }
}
