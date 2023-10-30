import Foundation

class EventHandler {

    private let validNewlineCharacters = ["\r\n", "\n", "\r"]
    private let dataBuffer: NSMutableData

    init() {
        dataBuffer = NSMutableData()
    }

    var currentBuffer: String? {
        return NSString(data: dataBuffer as Data, encoding: String.Encoding.utf8.rawValue) as String?
    }

    func append(data: Data?) -> [SSEEvent] {
        guard let data = data else { return [] }
        dataBuffer.append(data)
        let events = extractEventsFromBuffer().compactMap { [weak self] eventString -> SSEEvent? in
            guard let self else { return nil }
            return SSEEvent(eventString: eventString, newLineCharacters: self.validNewlineCharacters)
        }
        return events
    }

    private func extractEventsFromBuffer() -> [String] {
        var events = [String]()

        var searchRange =  NSRange(location: 0, length: dataBuffer.length)
        while let foundRange = searchFirstEventDelimiter(in: searchRange) {
            let dataChunk = dataBuffer.subdata(
                with: NSRange(location: searchRange.location, length: foundRange.location - searchRange.location)
            )
            if let text = String(bytes: dataChunk, encoding: .utf8) {
                events.append(text)
            }
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = dataBuffer.length - searchRange.location
        }
        dataBuffer.replaceBytes(in: NSRange(location: 0, length: searchRange.location), withBytes: nil, length: 0)
        return events
    }

    private func searchFirstEventDelimiter(in range: NSRange) -> NSRange? {
        let delimiters = validNewlineCharacters.map {
            "\($0)\($0)".data(using: String.Encoding.utf8)
        }
        for delimiter in delimiters {
            guard let delimiter = delimiter else { continue }
            let foundRange = dataBuffer.range(
                of: delimiter, options: NSData.SearchOptions(), in: range
            )
            if foundRange.location != NSNotFound {
                return foundRange
            }
        }
        return nil
    }
}

