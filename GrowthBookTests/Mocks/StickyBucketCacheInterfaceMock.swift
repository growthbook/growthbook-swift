//
//  StickyBucketCacheInterfaceMock.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/5/25.
//

import Foundation
@testable import GrowthBook

class StickyBucketCacheInterfaceMock: StickyBucketCacheInterface {
    var docs: [String: GrowthBook.StickyAssignmentsDocument] = [:]

    func stickyAssignment(for key: String) throws -> GrowthBook.StickyAssignmentsDocument? {
        docs[key]
    }

    func updateStickyAssignment(_ value: GrowthBook.StickyAssignmentsDocument?, for key: String) throws {
        docs[key] = value
    }

    func clearCache() throws {
        docs.removeAll()
    }
}
