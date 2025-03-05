import Foundation
import CommonCrypto
import CryptoKit

/// Interface for Caching Layer
public protocol CachingLayer: AnyObject {
    func saveContent(fileName: String, content: Data)
    func getContent(fileName: String) -> Data?
    func setCacheKey(_ key: String)
}

/// This is actual implementation of Caching Layer in iOS
public class CachingManager: CachingLayer {
    
    public static let shared = CachingManager()

    static func keyHash(_ input: String) -> String {
        input.sha256HashString
    }

    private var cacheDirectoryURL: URL
    private var cacheKey: String = ""

    init(cacheDirectoryURL: URL = CacheDirectory.applicationSupport.url) {
        self.cacheDirectoryURL = cacheDirectoryURL
    }
    
    func getData(fileName: String) -> Data? {
        return getContent(fileName: fileName)
    }

    func putData(fileName: String, content: Data) {
        saveContent(fileName: fileName, content: content)
    }

    func updateCacheDirectory(_ directory: CacheDirectory) {
        updateCacheDirectoryURL(directory.url)
    }

    func updateCacheDirectoryURL(_ directoryURL: URL) {
        cacheDirectoryURL = directoryURL
    }

    public func setCacheKey(_ key: String) {
        self.cacheKey = Self.keyHash(key)
    }

    /// Save content in cache
    public func saveContent(fileName: String, content: Data) {
        let fileManager = FileManager.default

        // Get File Path
        let filePath = getTargetFile(fileName: fileName)
        let fileURL = NSURL.fileURL(withPath: filePath)

        // Check if file already exists and delete if so
        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logger.error("Failed remove error: \(error.localizedDescription)")
            }
        }

        // Write contents in file
        fileManager.createFile(atPath: filePath, contents: content, attributes: nil)
    }

    /// Get Content from cache
    public func getContent(fileName: String) -> Data? {
        let fileManager = FileManager.default

        // Get File Path
        let filePath = getTargetFile(fileName: fileName)

        // Check if file exists
        if fileManager.fileExists(atPath: filePath) {
            // Read File Contents
            if let jsonContents = fileManager.contents(atPath: filePath) {
                return jsonContents
            }
        }

        return nil
    }

    /// Get Target File Path in internal memory
    func getTargetFile(fileName: String) -> String {
        // Get Documents Directory Path
        let directoryPath = cacheDirectoryURL.path
        // Append Folder name
        let targetFolderPath = directoryPath + "/GrowthBook-Cache-\(cacheKey)"

        let fileManager = FileManager.default
        // Check if folder exists
        if !fileManager.fileExists(atPath: targetFolderPath) {
            // Create folder for GrowthBook
            do {
                try fileManager.createDirectory(at: NSURL.fileURL(withPath: targetFolderPath),
                                                withIntermediateDirectories: true)
            } catch {
                logger.error("Failed created directory: \(error.localizedDescription)")
            }
        }

        // Remove txt suffix if coming in fileName
        let file = fileName.replacingOccurrences(of: ".txt", with: "")

        // Create complete filePath for targetFileName & internal Memory Folder
        return "\(targetFolderPath)/\(file).txt"
    }

    /// This function removes all files and subdirectories within the designated cache directory, which is a specific subdirectory within the app's cache directory.
    public func clearCache() {
        let directoryPath = cacheDirectoryURL.path

        let targetFolderPath = directoryPath + "/GrowthBook-Cache-\(cacheKey)"
        let fileManager = FileManager.default

        // Check if folder exists
        if fileManager.fileExists(atPath: targetFolderPath) {
            do {
                try fileManager.removeItem(atPath: targetFolderPath)
            } catch {
                logger.error("Failed to clear cache: \(error.localizedDescription)")
            }
        } else {
            logger.warning("Cache directory does not exist. Nothing to clear.")
        }
    }
}

/// This enumeration provides a convenient way to interact with various cache directories, simplifying the process of accessing and managing them using the FileManager API.
public enum CacheDirectory: Sendable {
    case applicationSupport
    case caches
    case documents
    case library
    case developerLibrary
    case customPath(String)

    /// Converts the enumeration case into the corresponding `FileManager.SearchPathDirectory` value, if applicable.
    var searchPathDirectory: FileManager.SearchPathDirectory? {
        switch self {
        case .applicationSupport:
            return .applicationSupportDirectory
        case .caches:
            return .cachesDirectory
        case .documents:
            return .documentDirectory
        case .library:
            return .libraryDirectory
        case .developerLibrary:
            return .developerDirectory
        case .customPath(_):
            return nil
        }
    }

    /// Retrieves the path to the cache directory represented by the enumeration case.
    var path: String? {
        switch self {
        case .applicationSupport, .caches, .documents, .library, .developerLibrary:
            return NSSearchPathForDirectoriesInDomains(
                searchPathDirectory ?? .cachesDirectory,
                .userDomainMask,
                true
            ).first
        case .customPath(let customPath):
            return customPath
        }
    }

    var url: URL {
        URL(fileURLWithPath: "\(path ?? "")", isDirectory: true)
    }
}
