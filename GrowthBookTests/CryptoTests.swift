//
//  CryptoTests.swift
//  GrowthBookTests
//
//  Created by Volodymyr Nazarkevych on 15.12.2022.
//

import XCTest

@testable import GrowthBook

final class CryptoTests: XCTestCase {
    
    func testDecryptEncrypt() throws {
        let keyString = "Ns04T5n9+59rl2x3SlNHtQ=="
        let stringForEncrypt = "{\"testfeature1\":{\"defaultValue\":true,\"rules\":[{\"condition\":{\"id\":\"1234\"},\"force\":false}]}}"
        let ivString = "vMSg2Bj/IurObDsWVmvkUg=="
        let crypto = Crypto()
        
        guard
            let keyBase64 = Data(base64Encoded: keyString),
            let ivBase64 = Data(base64Encoded: ivString),
            let stringForEncryptBase64 = stringForEncrypt.data(using: .utf8),
            let encryptText = try? crypto.encrypt(key: keyBase64.map{$0}, iv: ivBase64.map{$0}, plainText: stringForEncryptBase64.map{$0}),
            let decryptText = try? crypto.decrypt(key: keyBase64.map{$0}, iv: ivBase64.map{$0}, cypherText: encryptText.map{$0})
        else {
            XCTFail()
            return
        }
                
        XCTAssertTrue(stringForEncrypt == String(decoding: decryptText, as: UTF8.self))
    }
}
