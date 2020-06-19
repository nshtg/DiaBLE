import Foundation
import CryptoKit


extension Data {
    var hex: String { self.reduce("", { $0 + String(format: "%02x", $1)}) }
    var string: String { String(decoding: self, as: UTF8.self) }
    var hexAddress: String { String(self.reversed().reduce("", { $0 + String(format: "%02X", $1) + ":"}).dropLast(1)) }
    var sha1: String { Insecure.SHA1.hash(data: self).makeIterator().reduce("", { $0 + String(format: "%02x", $1)}) }

    func hexDump(address: Int = -1, header: String = "") -> String {
        var offset = startIndex
        var offsetEnd = offset
        var str = header.isEmpty ? "" : "\(header)\n"
        while offset < endIndex {
            _ = formIndex(&offsetEnd, offsetBy: 8, limitedBy: endIndex)
            if address != -1 { str += String(format: "%X", address + offset) + "  " }
            str += "\(self[offset ..< offsetEnd].reduce("", { $0 + String(format: "%02X", $1) + " "}))"
            str += String(repeating: "   ", count: 8 - distance(from: offset, to: offsetEnd))
            str += "\(self[offset ..< offsetEnd].reduce(" ", { $0 + ((isprint(Int32($1)) != 0) ? String(Unicode.Scalar($1)) : "." ) }))\n"
            _ = formIndex(&offset, offsetBy: 8, limitedBy: endIndex)
        }
        str.removeLast()
        return str
    }
}


extension String {
    var base64: String? { self.data(using: .utf8)?.base64EncodedString() }
    var base64Data: Data? { Data(base64Encoded: self) }
    var sha1: String { self.data(using: .ascii)!.sha1 }

    var bytes: [UInt8] {
        var bytes = [UInt8]()
        if !self.contains(" ") {
            var offset = self.startIndex
            while offset < self.endIndex {
                let hex = self[offset...index(after: offset)]
                bytes.append(UInt8(hex, radix: 16)!)
                formIndex(&offset, offsetBy: 2)
            }
        } else {
            /// Convert the NFCReader hex dump
            for line in self.split(separator: "\n") {
                let column = line.contains("  ") ? line.components(separatedBy: "  ")[1] : String(line)
                for hex in column.split(separator: " ").suffix(8) {
                    bytes.append(UInt8(hex, radix: 16)!)
                }
            }
        }
        return bytes
    }

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
        formatter.dateFormat = "MMM-dd HH:mm"
        return formatter.string(from: self)
    }
    var dateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
    var local: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}
