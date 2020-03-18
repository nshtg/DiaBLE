import Foundation
import SwiftUI


enum WatchType: String, CaseIterable, Hashable, Codable, Identifiable {
    case none, appleWatch, watlaa
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none:       return "Any"
        case .appleWatch: return AppleWatch.name
        case .watlaa:     return Watlaa.name
        }
    }
    var type: AnyClass {
        switch self {
        case .none:       return Watch.self
        case .appleWatch: return AppleWatch.self
        case .watlaa:     return Watlaa.self
        }
    }
}


class Watch: Device {
    override class var type: DeviceType { DeviceType.watch(.none) }
    @Published var transmitter: Transmitter? = Transmitter()
}


class AppleWatch: Watch {
    override class var type: DeviceType { DeviceType.watch(.appleWatch) }
    override class var name: String { "Apple Watch" }
}
