import Foundation


extension Data {
    var hex: String { self.reduce("", { $0 + String(format: "%02x", $1)}) }
    var string: String { String(decoding: self, as: UTF8.self) }
    var hexAddress: String { String(self.reduce("", { $0 + String(format: "%02X", $1) + ":"}).dropLast(1)) }
}


extension String {
    var base64: String? { self.data(using: .utf8)?.base64EncodedString() }
    var base64Data: Data? { Data(base64Encoded: self) }

    func matches(_ pattern: String) -> Bool {
        return pattern.split(separator: " ").contains { self.lowercased().contains($0.lowercased()) }
    }
}


extension Date {
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: self)
    }
    var shortDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM-d HH:mm"
        return formatter.string(from: self)
    }
    var dateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM-d HH:mm:ss"
        return formatter.string(from: self)
    }
    var local: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}
