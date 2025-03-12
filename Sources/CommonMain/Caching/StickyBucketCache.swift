//
//  StickyBucketCache.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/21/25.
//

import Foundation
import Combine

/// Sticky bucket cache interface.
public protocol StickyBucketCacheInterface: Sendable {
    /// Returns stored `StickyAssignmentsDocument` for a given key.
    /// - Parameter key: A key to return value for.
    func stickyAssignment(for key: String) throws -> StickyAssignmentsDocument?

    /// Stores a new `StickyAssignmentsDocument` for a given key.
    /// - Parameters:
    ///   - value: A new value to store.
    ///   - key: A key to sat value for.
    func updateStickyAssignment(_ value: StickyAssignmentsDocument?, for key: String) throws

    /// Clears the sticky bucket cache.
    func clearCache() throws
}

/// `StickyBucketCacheInterface` with a file storage.
public protocol StickyBucketFileStorageCacheInterface: StickyBucketCacheInterface {
    func updateCacheDirectoryURL(_ directoryURL: URL)
}

/// Default implementation of the `StickyBucketFileStorageCacheInterface`.
final public class StickyBucketFileStorageCache {
    private struct MutableState {
        var directoryURL: URL
        let fileManager: FileManager
        var storage: KeyedStorageBox<StickyAssignmentsDocument>
    }

    private let mutableState: Protected<MutableState>

    private init(
        directoryURL: URL,
        storageBox: KeyedStorageBox<StickyAssignmentsDocument>,
        fileManager: FileManager = .default
    ) {
        self.mutableState = .init(.init(directoryURL: directoryURL, fileManager: fileManager, storage: storageBox))
    }
    
    /// Creates a new `StickyBucketFileStorageCache` with a given params.
    ///
    /// - Parameters:
    ///   - directoryURL: A directory `URL` where to store cache.
    ///   - storage: A keyed storage interface.
    ///   - fileManager: A file manager for the underlying `FileStorage`.
    ///
    ///   - Note: Used for testing.
    convenience init<Storage: KeyedStorageInterface>(
        directoryURL: URL,
        storage: Storage,
        fileManager: FileManager = .default
    ) where Storage.Value == StickyAssignmentsDocument {
        self.init(directoryURL: directoryURL, storageBox: .init(storage), fileManager: fileManager)
    }

    private convenience init<Storage: StorageInterface>(
        directoryURL: URL,
        storageBuilder: @escaping (_ directoryURL: URL, _ key: String) -> Storage,
        fileManager: FileManager = .default
    ) where Storage.Value == StickyAssignmentsDocument {
        self.init(
            directoryURL: directoryURL,
            storage: KeyedStorageCache { storageBuilder(directoryURL, $0) },
            fileManager: fileManager
        )
    }

    public static func withFileCacheStorage(
        directoryURL: URL,
        fileManager: FileManager = .default
    ) -> StickyBucketFileStorageCache {
        .init(
            directoryURL: directoryURL,
            storageBuilder: Self.fileStorageBuilder(fileManager: fileManager),
            fileManager: fileManager
        )
    }

    private static func fileStorageBuilder(fileManager: FileManager) -> (_ directoryURL: URL, _ key: String) -> FileStorage<StickyAssignmentsDocument> {
        {
            FileStorage(fileURL: $0.appendingPathComponent($1, isDirectory: false), fileManager: fileManager)
        }
    }
}

extension StickyBucketFileStorageCache: StickyBucketCacheInterface {
    public func stickyAssignment(for key: String) throws -> StickyAssignmentsDocument? {
        try mutableState.read { try $0.storage.value(for: key) }
    }
    
    public func updateStickyAssignment(_ value: StickyAssignmentsDocument?, for key: String) throws {
        try mutableState.read { try $0.storage.updateValue(value, for: key) }
    }

    public func clearCache() throws {
        try mutableState.read {
            try $0.storage.reset()
            if $0.fileManager.fileExists(atPath: $0.directoryURL.path) {
                try $0.fileManager.removeItem(at: $0.directoryURL)
            }
        }
    }
}

extension StickyBucketFileStorageCache: StickyBucketFileStorageCacheInterface {
    public func updateCacheDirectoryURL(_ directoryURL: URL) {
        mutableState.write { mutableState in
            mutableState.directoryURL = directoryURL
            let protectedFileManager: Protected<FileManager> = Protected<FileManager>.init(mutableState.fileManager)
            mutableState.storage = KeyedStorageBox<StickyAssignmentsDocument>(KeyedStorageCache { Self.fileStorageBuilder(fileManager: protectedFileManager.read())(directoryURL, $0) })
        }
    }
}
