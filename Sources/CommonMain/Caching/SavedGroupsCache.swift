//
//  SavedGroupsCache.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/21/25.
//

import Foundation

/// Saved groups cache interface.
protocol SavedGroupsCacheInterface: AnyObject {
    /// Returns cached saved groups.
    func savedGroups() throws -> JSON?
    /// Updates cached groups with a given `value`.
    /// - Parameter value: A new groups to cache.
    func updateSavedGroups(_ value: JSON?) throws
    /// Clears the saved groups cache.
    func clearCache() throws
}

/// Default implementation of the `SavedGroupsCacheInterface`.
final class SavedGroupsCache: SavedGroupsCacheInterface {
    private let storage: StorageBox<JSON>

    init<Storage: StorageInterface>(storage: Storage) where Storage.Value == JSON {
        self.storage = .init(storage)
    }

    func savedGroups() throws -> JSON? {
        try storage.value()
    }

    func updateSavedGroups(_ value: JSON?) throws {
        try storage.updateValue(value)
    }

    func clearCache() throws {
        try storage.reset()
    }
}
