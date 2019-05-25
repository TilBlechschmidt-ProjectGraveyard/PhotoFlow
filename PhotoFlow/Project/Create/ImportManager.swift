//
//  ImportManager.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 19.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Photos

class ImportManager {
    let imageManager = PHImageManager.default()

    func resource(for asset: PHAsset) -> PHAssetResource? {
        return PHAssetResource.assetResources(for: asset).first
    }

    func originalFileName(for asset: PHAsset) -> String? {
        return resource(for: asset)?.originalFilename
    }

    func fileSize(for asset: PHAsset) -> Int64? {
        return resource(for: asset)?.value(forKey: "fileSize") as? Int64
    }

    func accumulatedFileSize(for assets: [PHAsset]) -> Int64 {
        return assets.reduce(0) { $0 + (fileSize(for: $1) ?? 0) }
    }

    func recentGroups() -> [[PHAsset]] {
        let options = PHFetchOptions()
        options.fetchLimit = 0
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let assets = PHAsset.fetchAssets(with: options)

        let maximumTimeIntervalBetweenPhotosInSameGroup: TimeInterval  = 60 * 30
        var assetGroups: [[PHAsset]] = []
        var currentAssetGroup: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image else {
                return
            }

            if let previousDate = currentAssetGroup.last?.creationDate,
                let currentDate = asset.creationDate,
                previousDate.timeIntervalSince(currentDate) > maximumTimeIntervalBetweenPhotosInSameGroup {
                assetGroups.append(currentAssetGroup)
                currentAssetGroup = []
            }

            currentAssetGroup.append(asset)
        }

        assetGroups.append(currentAssetGroup)

        return assetGroups
    }
}
