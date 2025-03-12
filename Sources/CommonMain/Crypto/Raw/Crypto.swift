//
//  Crypto.swift
//  GrowthBook
//
//  Created by Volodymyr Nazarkevych on 14.12.2022.
//

import Foundation
import CommonCrypto

protocol CryptoProtocol: AnyObject, Sendable {
    func getFeatures(from encryptedString: String, using encryptionKey: String) throws -> Features

    func getSavedGroups(from encryptedString: String, using encryptionKey: String) throws -> JSON

    func getExperiments(from encryptedString: String, using encryptionKey: String) throws -> [Experiment]

    func decryptAndDecode<T: Decodable>(from encryptedString: String, using encryptionKey: String) throws -> T
}

final class Crypto: CryptoProtocol {
    private func encrypt(key: [UInt8], iv: [UInt8], plainText: [UInt8]) throws -> [UInt8] {
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
    
    private func decrypt(key: [UInt8], iv: [UInt8], cypherText: [UInt8]) throws -> [UInt8] {
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

    /// Decryption error.
    enum DecryptionError: Error {
        /// Encrypted string must contain 2 sting components separated by a dot (`.`).
        case invalidEncryptedString
        /// Encryption key is not valid Base64 encoded string.
        case encryptionKeyIsNotValidBase64EncodedString
        /// Initialization vector is not valid Base64 encoded string.
        ///
        /// - Note: iv is the first component in the encoded string.
        case ivIsNotValidBase64EncodedString
        /// Cipher text vector is not valid Base64 encoded string.
        ///
        /// - Note: cipher is the second component in the encoded string.
        case cipherIsNotValidBase64EncodedString

        /// Invalid encryption key size
        ///
        /// The Base64 encoded encryption key size must be 128, 192, or 256 bits length.
        case invalidEncryptionKeySize

        /// Invalid initial vector size.
        ///
        /// Initial vector size must be 128 bits length.
        case invalidInitialVectorSize

        /// Invalid cipher text size.
        ///
        /// Cipher text size length must be multiple of 128 bits.
        case invalidCipherTextSize
    }

    private func decryptData(from encryptedString: String, using encryptionKey: String) throws -> Data {
        let arrayEncryptedString = encryptedString.components(separatedBy: ".")
        guard arrayEncryptedString.count >= 2 else {
            throw DecryptionError.invalidEncryptedString
        }

        let iv = arrayEncryptedString[0]
        let cipherText = arrayEncryptedString[1]

        guard let encryptionKeyBase64 = Data(base64Encoded: encryptionKey) else {
            throw DecryptionError.encryptionKeyIsNotValidBase64EncodedString
        }

        guard let ivBase64 = Data(base64Encoded: iv) else {
            throw DecryptionError.encryptionKeyIsNotValidBase64EncodedString
        }

        guard let cipherTextBase64 = Data(base64Encoded: cipherText) else {
            throw DecryptionError.cipherIsNotValidBase64EncodedString
        }

        guard [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(encryptionKeyBase64.count) else {
            throw DecryptionError.invalidEncryptionKeySize
        }

        guard iv.count == kCCBlockSizeAES128 else {
            throw DecryptionError.invalidInitialVectorSize
        }

        guard cipherTextBase64.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw DecryptionError.invalidCipherTextSize
        }

        let plainTextBuffer: [UInt8]
        do {
            plainTextBuffer = try decrypt(key: [UInt8](encryptionKeyBase64), iv: [UInt8](ivBase64), cypherText: [UInt8](cipherTextBase64))
        } catch {
            throw error
        }

        return Data(plainTextBuffer)
    }

    internal func decryptAndDecode<T: Decodable>(from encryptedString: String, using encryptionKey: String) throws -> T {
        let data = try decryptData(from: encryptedString, using: encryptionKey)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Use encryption key to get features from `encryptedString`.
    ///
    /// - Parameters:
    ///   - encryptedString: Encrypted features.
    ///   - encryptionKey: The key to encrypt with; must be a supported size: 128, 192, or 256 bits.
    /// - Returns: The features.
    func getFeatures(from encryptedString: String, using encryptionKey: String) throws -> Features {
        try decryptAndDecode(from: encryptedString, using: encryptionKey)
    }
    
    /// Returns decrypted saved groups.
    ///
    /// - Parameters:
    ///   - encryptedString: Encrypted saved groups.
    ///   - encryptionKey: The key to encrypt with; must be a supported size: 128, 192, or 256 bits.
    func getSavedGroups(from encryptedString: String, using encryptionKey: String) throws -> JSON {
        try decryptAndDecode(from: encryptedString, using: encryptionKey)
    }
    
    /// Returns decrypted experiments.
    ///
    /// - Parameters:
    ///   - encryptedString: Encrypted saved groups.
    ///   - encryptionKey: The key to encrypt with; must be a supported size: 128, 192, or 256 bits.
    func getExperiments(from encryptedString: String, using encryptionKey: String) throws -> [Experiment] {
        try decryptAndDecode(from: encryptedString, using: encryptionKey)
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
