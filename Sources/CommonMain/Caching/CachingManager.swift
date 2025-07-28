import Foundation
import CommonCrypto

/// Interface for Caching Layer
@objc public protocol CachingLayer: AnyObject {
    func saveContent(fileName: String, content: Data)
    func getContent(fileName: String) -> Data?
    func setCacheKey(_ key: String)
    func clearCache()
    func setSystemCacheDirectory(_ directory: CacheDirectory)
    func setCustomCachePath(_ path: String)
}

/// This is actual implementation of Caching Layer in iOS
@objc public class CachingManager: NSObject, CachingLayer {
    
    private var cacheDirectory = CacheDirectory.applicationSupport
    private var customCachePath: String?
    private var cacheKey: String = ""
    
    init(apiKey: String? = nil) {
        super.init()
        if let apiKey {
            self.setCacheKey(apiKey)
        }
    }
    
    public func setCacheKey(_ key: String) {
        self.cacheKey = sha256Hash(key)
    }
    
    func sha256Hash(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        let key = hash.map { String(format: "%02x", $0) }.joined()
        return String(key.prefix(5))
    }

    /// Set a custom cache saving directory
    @objc public func setCustomCachePath(_ path: String) {
        self.customCachePath = path
    }
    
    @objc public func setSystemCacheDirectory(_ directory: CacheDirectory) {
        cacheDirectory = directory
        self.customCachePath = nil
    }
    
    /// Save content in cache
    @objc public func saveContent(fileName: String, content: Data) {
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
    @objc public func getContent(fileName: String) -> Data? {
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
    @objc func getTargetFile(fileName: String) -> String {
        // Get Documents Directory Path
        guard let directoryPath = customCachePath ?? cacheDirectory.path else { return "" }
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
    @objc public func clearCache() {
                
        guard let directoryPath = self.customCachePath ?? cacheDirectory.path else {
            logger.error("Failed to retrieve directory path.")
            return
        }
        
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
@objc public enum CacheDirectory: Int {
    case applicationSupport
    case caches
    case documents
    case library
    case developerLibrary
    
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
        }
    }
}
