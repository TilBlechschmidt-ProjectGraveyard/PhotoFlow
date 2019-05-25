//
//  UIApplication+Directories.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 19.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

extension UIApplication {
    static func cacheDirectory() -> URL {
        guard let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Unable to get system cache directory")
        }

        return cacheURL
    }

    static func documentCreationCacheDirectory() -> URL {
        let cacheURL = UIApplication.cacheDirectory().appendingPathComponent("DocumentCreation")
//        FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil)
        return cacheURL
    }

    static func documentsDirectory() -> URL {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to get system docs directory")
        }

        return documentsURL
    }

    static func clearCaches() {
        let documentCreationCache = UIApplication.documentCreationCacheDirectory()
        let paths = try? FileManager.default.contentsOfDirectory(atPath: documentCreationCache.path)

        paths?.forEach {
            // TODO Take some action if this fails
            try? FileManager.default.removeItem(at: documentCreationCache.appendingPathComponent($0))
        }
    }
}
