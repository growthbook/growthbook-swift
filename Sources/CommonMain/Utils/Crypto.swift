//
//  Crypto.swift
//  GrowthBook
//
//  Created by Volodymyr Nazarkevych on 14.12.2022.
//

import Foundation
import CommonCrypto

@objc public protocol CryptoProtocol: AnyObject {
    func encrypt(key: [UInt8], iv: [UInt8], plainText: [UInt8]) throws -> [UInt8]
    func decrypt(key: [UInt8], iv: [UInt8], cypherText: [UInt8]) throws -> [UInt8]
}

class Crypto: CryptoProtocol {
    func encrypt(key: [UInt8], iv: [UInt8], plainText: [UInt8]) throws -> [UInt8] {
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
    
    /// Decrypts data that was encrypted using AES with PKCS#7 padding in CBC mode.
    ///
    /// - note: PKCS#7 padding is also known as PKCS#5 padding.
    ///
    /// - Parameters:
    ///   - key: The key to encrypt with; must be a supported size (128, 192, 256).
    ///   - iv: The initialisation vector; must be of size 16.
    ///   - cypherText: The encrypted data; it’s length must be an even multiple of
    ///     16.
    /// - Returns: The decrypted data.
    
    func decrypt(key: [UInt8], iv: [UInt8], cypherText: [UInt8]) throws -> [UInt8] {
        /// The key size must be 128, 192, or 256.
        ///
        /// The IV size must match the block size.
        ///
        /// The cipherText must be a multiple of the block size.

        guard
            [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(key.count),
            iv.count == kCCBlockSizeAES128,
            cypherText.count.isMultiple(of: kCCBlockSizeAES128)
        else {
            throw CryptoError(code: kCCParamError)
        }

        /// Padding can expand the data on encryption, but on decryption the data can
        /// only shrink so we use the cypherText size as our plaintext size.

        var plaintext = [UInt8](repeating: 0, count: cypherText.count)
        var plaintextCount = 0
        let err = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            key, key.count,
            iv,
            cypherText, cypherText.count,
            &plaintext, plaintext.count,
            &plaintextCount
        )
        guard err == kCCSuccess else {
            throw CryptoError(code: err)
        }
        
        /// Trim any unused bytes off the plaintext.
        
        assert(plaintextCount <= plaintext.count)
        plaintext.removeLast(plaintext.count - plaintextCount)

        return plaintext
    }
}

struct CryptoError: Error {
    var code: CCCryptorStatus
}

extension CryptoError {
    init(code: Int) {
        self.init(code: CCCryptorStatus(code))
    }
}
