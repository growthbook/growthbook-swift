import Foundation

enum SSEEvent {
    case event(id: String?, event: String?, data: String?, time: String?)
    
    init?(eventString: String?, newLineCharacters: [String]) {
        guard let eventString = eventString else { return nil }
        
        if eventString.hasPrefix(":") {
            return nil
        }
        self = SSEEvent.parseEvent(eventString, newLineCharacters: newLineCharacters)
    }
    
    var id: String? {
        guard case let .event(id, _, _, _) = self else { return nil }
        return id
    }
    
    var event: String? {
        guard case let .event(_, name, _, _) = self else { return nil }
        return name
    }
    
    var data: String? {
        guard case let .event(_, _, data, _) = self else { return nil }
        return data
    }
    
    var retryTime: Int? {
        guard case let .event(_, _, _, time) = self, let time = time else { return nil }
        return Int(time.trimmingCharacters(in: CharacterSet.whitespaces))
    }
    
    var onlyRetryEvent: Bool? {
        guard case let .event(id, name, data, time) = self else { return nil }
        let otherThanTime = id ?? name ?? data
        
        if otherThanTime == nil && time != nil {
            return true
        }
        
        return false
        
    }
}

private extension SSEEvent {
    
    static func parseEvent(_ eventString: String, newLineCharacters: [String]) -> SSEEvent {
        var event: [String: String?] = [:]
        
        for line in eventString.components(separatedBy: CharacterSet.newlines) as [String] {
            let (akey, value) = SSEEvent.parseLine(line, newLineCharacters: newLineCharacters)
            guard let key = akey else { continue }
            
            if let value = value, let previousValue = event[key] ?? nil {
                event[key] = "\(previousValue)\n\(value)"
            } else if let value = value {
                event[key] = value
            } else {
                event[key] = nil
            }
        }
        
        return .event(
            id: event["id"] ?? nil,
            event: event["event"] ?? nil,
            data: event["data"] ?? nil,
            time: event["retry"] ?? nil
        )
    }
    
    static func parseLine(_ line: String, newLineCharacters: [String]) -> (key: String?, value: String?) {
        var key: NSString?, value: NSString?
        let scanner = Scanner(string: line)
        if #available(iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            if let scannedKey = scanner.scanUpToString(":") {
                key = scannedKey as NSString
            }
            _ = scanner.scanString(":")
        } else {
            scanner.scanUpTo(":", into: &key)
            scanner.scanString(":", into: nil)
        }
        
        for newline in newLineCharacters {
            if #available(iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                if let scannedValue = scanner.scanUpToString(newline) {
                    value = scannedValue as NSString
                    break
                }
            } else {
                if scanner.scanUpTo(newline, into: &value) {
                    break
                }
            }
        }
        
        if key != "event" && value == nil {
            value = ""
        }
        
        return (key as String?, value as String?)
    }
}
