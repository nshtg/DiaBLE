import Foundation
import CoreBluetooth


class BLE {

    static let knownDevices: [Device.Type] = DeviceType.allCases.filter{ $0.id != "none" }.map{ ($0.type as! Device.Type) }
    static let knownDevicesIds: [String]   = DeviceType.allCases.filter{ $0.id != "none" }.map{ $0.id }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        
        case device        = "180A"
        case systemID      = "2A23"
        case model         = "2A24"
        case serial        = "2A25"
        case firmware      = "2A26"
        case hardware      = "2A27"
        case software      = "2A28"
        case manufacturer  = "2A29"
        // Libre 2
        case regulatoryCertificationDataList = "2A2A"
        case pnpID         = "2A50"

        case battery       = "180F"
        case batteryLevel  = "2A19"

        case time          = "1805"
        case currentTime   = "2A2B"
        case localTimeInfo = "2A0F"

        case dfu           = "FE59"

        // Mi Band
        case immediateAlert    = "1802"
        case alertNotification = "1811"
        case heartRate         = "180D"

        // Apple
        case nearby        = "9FA480E0-4967-4542-9390-D343DC5D04AE"
        case nearby1       = "AF0BADB1-5B99-43CD-917A-A77BC549E3CC"

        case continuity    = "D0611E78-BBB4-4591-A5F8-487910AE4366"
        case continuity1   = "8667556C-9A37-4C91-84ED-54EE27D90049"


        var description: String {
            switch self {
            case .device:        return "device information"
            case .systemID:      return "system id"
            case .model:         return "model number"
            case .serial:        return "serial number"
            case .firmware:      return "firmware version"
            case .hardware:      return "hardware revision"
            case .software:      return "software revision"
            case .manufacturer:  return "manufacturer"
            case .regulatoryCertificationDataList: return "IEEE 11073-20601 regulatory certification data list"
            case .pnpID:         return "pnp id"
            case .battery:       return "battery"
            case .batteryLevel:  return "battery level"
            case .time:          return "time"
            case .currentTime:   return "current time"
            case .localTimeInfo: return "local time information"
            case .dfu:           return "device firmware update"
            case .immediateAlert:    return "immediate alert"
            case .alertNotification: return "alert notification"
            case .heartRate:         return "heart rate"
            case .nearby:        return "nearby"
            case .nearby1:       return "nearby"
            case .continuity:    return "continuity"
            case .continuity1:   return "continuity"
            }
        }
    }
}


extension CBCharacteristicProperties: CustomStringConvertible {
    public var description: String {
        var d = [String: Bool]()
        d["Broadcast"]                  = self.contains(.broadcast)
        d["Read"]                       = self.contains(.read)
        d["WriteWithoutResponse"]       = self.contains(.writeWithoutResponse)
        d["Write"]                      = self.contains(.write)
        d["Notify"]                     = self.contains(.notify)
        d["Indicate"]                   = self.contains(.indicate)
        d["AuthenticatedSignedWrites"]  = self.contains(.authenticatedSignedWrites)
        d["ExtendedProperties"]         = self.contains(.extendedProperties)
        d["NotifyEncryptionRequired"]   = self.contains(.notifyEncryptionRequired)
        d["IndicateEncryptionRequired"] = self.contains(.indicateEncryptionRequired)
        return "\(d.filter{$1}.keys)"
    }
}


enum DeviceType: CaseIterable, Hashable, Identifiable {

    case none
    case transmitter(TransmitterType)
    case watch(WatchType)

    static var allCases: [DeviceType] {
        return TransmitterType.allCases.map{.transmitter($0)} + WatchType.allCases.map{.watch($0)}
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
    var name: String = "Unknown"


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

    func write(_ bytes: [UInt8], for uuid: String = "") {
        if uuid.isEmpty {
            peripheral?.writeValue(Data(bytes), for: writeCharacteristic!, type: .withoutResponse)
        } else {
            peripheral?.writeValue(Data(bytes), for: characteristics[uuid]!, type: .withoutResponse)
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
