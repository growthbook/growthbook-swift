//
//  ProtectedTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/24/25.
//

import Foundation
import XCTest

@testable import GrowthBook

final class ProtectedTests: XCTestCase {
    func testSafetyClosures() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.read { $0 }
            protected.write { value in value = "\(i)" }
        }

        // Then
        XCTAssertNotEqual(protected.read { $0 }, initialValue)
    }

    func testSafetyDirect() {
        // Given
        let initialValue = "value"
        let protected = Protected<String>(initialValue)

        // When
        DispatchQueue.concurrentPerform(iterations: 10_000) { i in
            _ = protected.read()
            protected.write("\(i)")
        }

        // Then
        XCTAssertNotEqual(protected.read { $0 }, initialValue)
    }
}
