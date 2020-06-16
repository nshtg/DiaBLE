import Foundation
import CoreBluetooth


enum DeviceType: CaseIterable, Hashable, Identifiable {

    case none
    case transmitter(TransmitterType)
    case watch(WatchType)

    static var allCases: [DeviceType] {
        return TransmitterType.allCases.map{.transmitter($0)} // + WatchType.allCases.map{.watch($0)}
    }

    var id: String {
        switch self {
        case .none:                  return "none"
        case .transmitter(let type): return type.id
        case .watch(let type):       return type.id
        }
    }

    var type: AnyClass {
        switch self {
        case .none:                  return Device.self
        case .transmitter(let type): return type.type
        case .watch(let type):       return type.type
        }
    }
}


class Device: ObservableObject {

    class var type: DeviceType { DeviceType.none }
    class var name: String { "Unknown" }

    class var knownUUIDs: [String] { [] }
    class var dataServiceUUID: String { "" }
    class var dataReadCharacteristicUUID: String { "" }
    class var dataWriteCharacteristicUUID: String { "" }

    var type: DeviceType = DeviceType.none
    @Published var name: String = "Unknown"


    /// Main app delegate to use its log()
    var main: MainDelegate!

    var peripheral: CBPeripheral?
    var characteristics = [String: CBCharacteristic]()

    /// Updated when notified by the Bluetooth manager
    @Published var state: CBPeripheralState = .disconnected

    var readCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?

    @Published var battery: Int = -1
    @Published var rssi: Int = 0
    var company: String = ""
    var model: String = ""
    var serial: String = ""
    var firmware: String = ""
    var hardware: String = ""
    var software: String = ""
    var manufacturer: String = ""
    var macAddress: Data = Data()

    var buffer = Data()

    init(peripheral: CBPeripheral, main: MainDelegate) {
        self.type = Self.type
        self.name = Self.name
        self.peripheral = peripheral
        self.main = main
    }

    init() {
        self.type = Self.type
        self.name = Self.name
    }

    // For UI testing
    convenience init(battery: Int, rssi: Int = 0, firmware: String = "", manufacturer: String = "", hardware: String = "", macAddress: Data = Data()) {
        self.init()
        self.battery = battery
        self.rssi = rssi
        self.firmware = firmware
        self.manufacturer = manufacturer
        self.hardware = hardware
        self.macAddress = macAddress
    }

    func write(_ bytes: [UInt8], for uuid: String = "", _ writeType: CBCharacteristicWriteType = .withoutResponse) {
        if uuid.isEmpty {
            peripheral?.writeValue(Data(bytes), for: writeCharacteristic!, type: writeType)
        } else {
            peripheral?.writeValue(Data(bytes), for: characteristics[uuid]!, type: writeType)
        }
    }

    func read(_ data: Data, for uuid: String) {
    }


    func readValue(for uuid: BLE.UUID) {
        peripheral?.readValue(for: characteristics[uuid.rawValue]!)
        main.debugLog("\(name): requested value for \(uuid)")
    }

    /// varying reading interval
    func readCommand(interval: Int = 5) -> [UInt8] { [] }

    func parseManufacturerData(_ data: Data) {
        main.log("Bluetooth: \(name)'s advertised manufacturer data: \(data.hex)" )
    }

}


enum TransmitterType: String, CaseIterable, Hashable, Codable, Identifiable {
    case none, blu, bubble, miaomiao
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none:     return "Any"
        case .blu:      return BluCon.name
        case .bubble:   return Bubble.name
        case .miaomiao: return MiaoMiao.name
        }
    }
    var type: AnyClass {
        switch self {
        case .none:     return Transmitter.self
        case .blu:      return BluCon.self
        case .bubble:   return Bubble.self
        case .miaomiao: return MiaoMiao.self
        }
    }
}


class Transmitter: Device {
    @Published var sensor: Sensor?
}


enum WatchType: String, CaseIterable, Hashable, Codable, Identifiable {
    case none, appleWatch
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none:       return "Any"
        case .appleWatch: return AppleWatch.name
        }
    }
    var type: AnyClass {
        switch self {
        case .none:       return Watch.self
        case .appleWatch: return AppleWatch.self
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
