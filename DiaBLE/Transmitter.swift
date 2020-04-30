import Foundation
import CoreBluetooth


enum TransmitterType: String, CaseIterable, Hashable, Codable, Identifiable {
    case none, bubble, miaomiao
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none:     return "Any"
        case .bubble:   return Bubble.name
        case .miaomiao: return MiaoMiao.name
        }
    }
    var type: AnyClass {
        switch self {
        case .none:     return Transmitter.self
        case .bubble:   return Bubble.self
        case .miaomiao: return MiaoMiao.self
        }
    }
}


class Transmitter: Device {
    @Published var sensor: Sensor?
}

