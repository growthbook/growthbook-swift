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

    /// Decrypts data that was encrypted using AES with PKCS#7 padding in CBC mode.
    ///
    /// - note: PKCS#7 padding is also known as PKCS#5 padding.
    ///
    /// - Parameters:
    ///   - key: The key to encrypt with; must be a supported size (128, 192, 256).
    ///   - iv: The initialisation vector; must be of size 16.
    ///   - cipherText: The encrypted data; it’s length must be an even multiple of
    ///     16.
    /// - Returns: The decrypted data.
    
    private func decrypt(encryptionKeyBytes: [UInt8], initialVectorBytes: [UInt8], cipherBytes: [UInt8]) throws -> [UInt8] {
        /// The key size must be 128, 192, or 256.
        ///
        /// The IV size must match the block size.
        ///
        /// The cipherText must be a multiple of the block size.

        guard
            [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(encryptionKeyBytes.count),
            initialVectorBytes.count == kCCBlockSizeAES128,
            cipherBytes.count.isMultiple(of: kCCBlockSizeAES128)
        else {
            throw CryptoError(code: kCCParamError)
        }

        /// Padding can expand the data on encryption, but on decryption the data can
        /// only shrink so we use the cypherText size as our plaintext size.

        var plaintext = [UInt8](repeating: 0, count: cipherBytes.count)
        var plaintextCount = 0
        let err = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            encryptionKeyBytes, encryptionKeyBytes.count,
            initialVectorBytes,
            cipherBytes, cipherBytes.count,
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
        /// Cipher data size length must be multiple of 128 bits.
        case invalidCipherDataSize
    }

    private func decryptData(from encryptedString: String, using encryptionKeyBase64EncodedString: String) throws -> Data {
        let arrayEncryptedString = encryptedString.components(separatedBy: ".")
        guard arrayEncryptedString.count >= 2 else {
            throw DecryptionError.invalidEncryptedString
        }

        let ivBase64EncodedString = arrayEncryptedString[0]
        let cipherTextBase64EncodedString = arrayEncryptedString[1]

        guard let encryptionKeyData = Data(base64Encoded: encryptionKeyBase64EncodedString) else {
            throw DecryptionError.encryptionKeyIsNotValidBase64EncodedString
        }

        guard let initialVectorData = Data(base64Encoded: ivBase64EncodedString) else {
            throw DecryptionError.ivIsNotValidBase64EncodedString
        }

        guard let cipherData = Data(base64Encoded: cipherTextBase64EncodedString) else {
            throw DecryptionError.cipherIsNotValidBase64EncodedString
        }

        guard [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(encryptionKeyData.count) else {
            throw DecryptionError.invalidEncryptionKeySize
        }

        guard initialVectorData.count == kCCBlockSizeAES128 else {
            throw DecryptionError.invalidInitialVectorSize
        }

        guard cipherData.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw DecryptionError.invalidCipherDataSize
        }

        let plainTextBuffer: [UInt8]
        do {
            plainTextBuffer = try decrypt(encryptionKeyBytes: encryptionKeyData.bytes, initialVectorBytes: initialVectorData.bytes, cipherBytes: cipherData.bytes)
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

extension Data {
    var bytes: [UInt8] { [UInt8](self) }
}

struct CryptoError: Error {
    var code: CCCryptorStatus
}

extension CryptoError {
    init(code: Int) {
        self.init(code: CCCryptorStatus(code))
    }
}
