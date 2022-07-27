import Foundation

/// Interface for Caching Layer
public protocol CachingLayer: AnyObject {
    func saveContent(fileName: String, content: Data)
    func getContent(fileName: String) -> Data?
}

/// This is actual implementation of Caching Layer in iOS
public class CachingManager: CachingLayer {
    static let shared = CachingManager()

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
                logger.error("Failed remove error:  \(error.localizedDescription)")
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
            guard let jsonContents = fileManager.contents(atPath: filePath) else { return nil }
            return jsonContents
        }

        return nil
    }

    /// Get Target File Path in internal memory
    func getTargetFile(fileName: String) -> String {
        // Get Documents Directory Path
        guard let directoryPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
        ).first else { return "" }
        // Append Folder name
        let targetFolderPath = directoryPath + "/GrowthBook-Cache"

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
}
