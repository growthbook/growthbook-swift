//
//  DecryptionUtils.swift
//  GrowthBook
//
//  Created by admin on 9/21/23.
//

import Foundation
import CommonCrypto

class DecryptionUtils {
    
    enum DecryptionError: Error {
        case invalidPayload
        case invalidEncryptionKey
        case decryptionFailed
    }
    
    static func decrypt(payload: String, encryptionKey: String) throws -> String {
        guard payload.contains(".") else {
            throw DecryptionError.invalidPayload
        }
        
        do {
            let parts = payload.split(separator: ".")
            let ivString = String(parts[0])
            let cipherTextString = String(parts[1])
            
            guard let ivData = Data(base64Encoded: ivString),
                  let encryptionKeyData = Data(base64Encoded: encryptionKey) else {
                throw DecryptionError.invalidPayload
            }
            
            let cipherTextData = Data(base64Encoded: cipherTextString)
            
            let decryptedData = try AESCryptor.decrypt(data: cipherTextData, key: encryptionKeyData, iv: ivData)
            
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                throw DecryptionError.decryptionFailed
            }
            
            return decryptedString
        } catch {
            throw DecryptionError.decryptionFailed
        }
    }
    
    private static func keyFromSecret(encryptionKey: String) -> Data {
        guard let keyData = Data(base64Encoded: encryptionKey) else {
            fatalError("Invalid encryption key")
        }
        return keyData
    }
}

class AESCryptor {
    
    static func decrypt(data: Data?, key: Data, iv: Data) throws -> Data {
        guard let inputData = data else {
            throw DecryptionUtils.DecryptionError.decryptionFailed
        }
        
        var buffer = [UInt8](repeating: 0, count: inputData.count + kCCBlockSizeAES128)
        var numBytesDecrypted = 0
        
        let status = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                inputData.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, inputData.count,
                        &buffer, buffer.count,
                        &numBytesDecrypted
                    )
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw DecryptionUtils.DecryptionError.decryptionFailed
        }
        
        return Data(buffer.prefix(numBytesDecrypted))
    }
}

class DecryptionException: Error {
    let errorMessage: String

    init(errorMessage: String) {
        self.errorMessage = errorMessage
    }
}
