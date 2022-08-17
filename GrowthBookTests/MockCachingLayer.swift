//
//  MockCachingLayer.swift
//  GrowthBookTests
//
//  Created by Viacheslav Karamov on 15/08/2022.
//

import Foundation
@testable import GrowthBook

class MockCachingLayer: CachingLayer {
    func saveContent(fileName: String, content: Data) {
    }
    
    func getContent(fileName: String) -> Data? {
        Data()
    }
}
