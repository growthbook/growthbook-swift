//
//  FeaturesCache.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/21/25.
//

import Foundation

/// `Features` cache interface.
protocol FeaturesCacheInterface: AnyObject, Sendable {
    /// Returns cached `Features`.
    func features() throws -> Features?
    /// Updates stored `Features`.
    /// - Parameter value: A new `Features` to cache.
    func updateFeatures(_ value: Features?) throws
    /// Updates stored `Features` with a given encoded `Data`.
    /// - Parameter data: An encoded `Features` `Data`.
    func setEncodedFeaturesRawData(_ data: Data) throws
    /// Clear the stored cache.
    func clearCache() throws
}

/// Default implementation of the `FeaturesCacheInterface`.
final class FeaturesCache: FeaturesCacheInterface {
    private let storage: DataStorageBox<Features>

    init<Storage: DataStorageInterface>(storage: Storage) where Storage.Value == Features {
        self.storage = .init(storage)
    }

    func features() throws -> Features? {
        try storage.value()
    }

    func updateFeatures(_ value: Features?) throws {
        try storage.updateValue(value)
    }

    func setEncodedFeaturesRawData(_ data: Data) throws {
        try storage.setRawData(data)
    }

    func clearCache() throws {
        try storage.reset()
    }
}
