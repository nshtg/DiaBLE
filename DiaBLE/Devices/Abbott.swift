import Foundation

class Abbott: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.abbott) }
    override class var name: String { "Abbott" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case abbottCustom     = "FDE3"
        case bleLogin         = "F001"
        case compositeRawData = "F002"

        var description: String {
            switch self {
            case .abbottCustom:      return "Abbott custom"
            case .bleLogin:          return "BLE login"
            case .compositeRawData:  return "composite raw data"
            }
        }
    }

    override class var knownUUIDs: [String] { UUID.allCases.map{$0.rawValue} }

    override class var dataServiceUUID: String { UUID.abbottCustom.rawValue }

}
