//
//  CryptoTests.swift
//  GrowthBookTests
//
//  Created by Volodymyr Nazarkevych on 15.12.2022.
//

import XCTest
import CommonCrypto

@testable import GrowthBook

extension Crypto {
    fileprivate func encrypt(key: [UInt8], iv: [UInt8], plainText: [UInt8]) throws -> [UInt8] {
        /// The key size must be 128, 192, or 256.
        ///
        /// The IV size must match the block size.

        guard
            [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(key.count),
            iv.count == kCCBlockSizeAES128
        else {
            throw CryptoError(code: kCCParamError)
        }

        /// Padding can expand the data, so we have to allocate space for that.  The
        /// rule for block cyphers, like AES, is that the padding only adds space on
        /// encryption (on decryption it can reduce space, obviously, but we don't
        /// need to account for that) and it will only add at most one block size
        /// worth of space.

        var cypherText = [UInt8](repeating: 0, count: plainText.count + kCCBlockSizeAES128)
        var cypherTextCount = 0
        let err = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            key, key.count,
            iv,
            plainText, plainText.count,
            &cypherText, cypherText.count,
            &cypherTextCount
        )
        guard err == kCCSuccess else {
            throw CryptoError(code: err)
        }

        /// The cypherText can expand by up to one block but it doesn’t always use the full block,
        /// so trim off any unused bytes.

        assert(cypherTextCount <= cypherText.count)
        cypherText.removeLast(cypherText.count - cypherTextCount)
        assert(cypherText.count.isMultiple(of: kCCBlockSizeAES128))

        return cypherText
    }
}

final class CryptoTests: XCTestCase {
    
    func testDecryptEncrypt() throws {
        let keyString = "Ns04T5n9+59rl2x3SlNHtQ=="
        let stringForEncrypt = #"{"testfeature1":{"defaultValue":true,"rules":[{"condition":{"id":"1234"},"force":false}]}}"#
        let ivString = "vMSg2Bj/IurObDsWVmvkUg=="
        let crypto = Crypto()

        guard
            let keyBase64 = Data(base64Encoded: keyString),
            let ivBase64 = Data(base64Encoded: ivString),
            let stringForEncryptBase64 = stringForEncrypt.data(using: .utf8)
        else {
            XCTFail()
            return
        }
        let encryptedBytes = try crypto.encrypt(key: [UInt8](keyBase64), iv: [UInt8](ivBase64), plainText: [UInt8](stringForEncryptBase64))

        guard var encryptedString = String(data: Data(encryptedBytes).base64EncodedData(), encoding: .utf8) else {
            return XCTFail()
        }
        encryptedString = "\(ivString).\(encryptedString)"
        let decryptText = try crypto.getFeatures(from: encryptedString, using: keyString)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let string = String(String(decoding: try encoder.encode(decryptText), as: UTF8.self))
        XCTAssertTrue(stringForEncrypt == string, "\(stringForEncrypt) must be equal to \(string)")
    }
}
