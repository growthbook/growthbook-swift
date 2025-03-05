//
//  String+Hash.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/5/25.
//

import CommonCrypto
import CryptoKit

extension String {
    var sha256HashString: String {
        guard let data = data(using: .utf8) else { return "" }

        let hashBytes: [UInt8]

        if #available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *) {
            hashBytes = [UInt8](SHA256.hash(data: data))
        } else {
            var hashedBytes: [UInt8] = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hashedBytes)
            }
            hashBytes = hashedBytes
        }

        return hashBytes.hexString
    }
}

extension [UInt8] {
    fileprivate var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
