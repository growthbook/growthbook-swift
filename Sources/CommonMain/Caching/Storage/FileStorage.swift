//
//  SingleFileStorage.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/20/25.
//

import Foundation

/// A thread-safe file storage for codable values.
final class FileStorage<Value: Codable> {
    /// An URL to file where encoded value is stored.
    private let fileURL: URL

    /// Stored value.
    ///
    /// Storing a copy in memory to reduce file read and decoding operations.
    ///
    /// The value is not read until first access. This allows to handle load and parse errors on first access.
    private let storedValue: Protected<Value?>

    /// Encoding closure.
    private let encode: @Sendable (Value) throws -> Data

    /// Decoding closure.
    private let decode: @Sendable (Data) throws -> Value

    private nonisolated(unsafe) let fileManager: FileManager

    init<Encoder: TopLevelEncoder, Decoder: TopLevelDecoder>(
        fileURL: URL,
        decoder: Decoder = JSONDecoder(),
        encoder: Encoder = JSONEncoder(),
        fileManager: FileManager = .default
    ) where Encoder.Output == Data, Decoder.Input == Data {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.encode = { try encoder.encode($0) }
        self.decode = {
            do {
                return try decoder.decode(Value.self, from: $0)
            } catch {
                throw SDKError.failedParsedData
            }
        }

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                self.storedValue = try .init(decode(Data(contentsOf: fileURL)))
            } catch {
                self.storedValue = .init(nil)
                try? self.reset()
            }
        } else {
            self.storedValue = .init(nil)
        }
    }

    private func readDataFromFile() throws -> Data? {
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw SDKError.failedToLoadData
        }
    }

    private func writeDataToFile(_ data: Data?) throws {
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data?.write(to: fileURL, options: .atomic)
    }
}

extension FileStorage: StorageInterface {
    func value() throws -> Value? {
        return storedValue.read()
    }

    func updateValue(_ value: Value?) throws {
        try storedValue.write { storedValue in
            storedValue = value
            let data: Data = try value.map(encode) ?? Data()
            try writeDataToFile(data)
        }
    }

    func reset() throws {
        try storedValue.write { storedValue in
            storedValue = nil
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
}

extension FileStorage: DataStorageInterface {
    func getRawData() throws -> Data? {
        try storedValue.read { _ in try readDataFromFile() }
    }
    
    func setRawData(_ data: Data?) throws {
        try storedValue.write { storedValue in
            storedValue = try data.map(decode)
            try writeDataToFile(data)
        }
    }
}

/// A type that defines methods for decoding.
///
/// - Note: Declared in Combine, but has higher requirements for iOS, tvOS, and watchOS
protocol TopLevelDecoder {
    /// The type this decoder accepts.
    associatedtype Input
    /// Decodes an instance of the indicated type.
    func decode<T>(_ type: T.Type, from: Self.Input) throws -> T where T : Decodable
}

/// A type that defines methods for encoding.
///
/// - Note: Declared in Combine, but has higher requirements for iOS, tvOS, and watchOS
protocol TopLevelEncoder {
    /// The type this encoder produces.
    associatedtype Output
    /// Encodes an instance of the indicated type.
    ///
    /// - Parameter value: The instance to encode.
    func encode<T>(_ value: T) throws -> Self.Output where T : Encodable
}

extension JSONDecoder: TopLevelDecoder {}
extension JSONEncoder: TopLevelEncoder {}
