//
//  GrowthBookCachingManagerInterface.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/20/25.
//

import Foundation
import Combine

protocol GrowthBookSDKCachingManagerInterface {
    /// `Features` cache.
    var featuresCache: FeaturesCacheInterface { get }
    /// Saved groups cache.
    var savedGroupsCache: SavedGroupsCacheInterface { get }
    // Clears features and saved groups caches.
    func clearCache() throws
}

/// Default implementation of the `GrowthBookSDKCachingManagerInterface`.
class GrowthBookSDKCachingManager: GrowthBookSDKCachingManagerInterface {
    let featuresCache: FeaturesCacheInterface
    let savedGroupsCache: SavedGroupsCacheInterface

    init(featuresCache: FeaturesCacheInterface, savedGroupsCache: SavedGroupsCacheInterface) {
        self.featuresCache = featuresCache
        self.savedGroupsCache = savedGroupsCache
    }

    func clearCache() throws {
        try featuresCache.clearCache()
        try savedGroupsCache.clearCache()
    }
}

extension GrowthBookSDKCachingManager {
    static func withFileStorage(
        directoryURL: URL,
        featuresCacheFilename: String,
        savedGroupsCacheFilename: String,
        fileManager: FileManager
    ) -> GrowthBookSDKCachingManager {
        .init(
            featuresCache: FeaturesCache(
                storage: FileStorage(fileURL: directoryURL.appendingPathComponent(featuresCacheFilename, isDirectory: false), fileManager: fileManager)
            ),
            savedGroupsCache: SavedGroupsCache(
                storage: FileStorage(fileURL: directoryURL.appendingPathComponent(savedGroupsCacheFilename, isDirectory: false), fileManager: fileManager)
            )
        )
    }
}
