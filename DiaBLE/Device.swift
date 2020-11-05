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

    // For log while testing
    convenience init(main: MainDelegate) {
        self.init()
        self.main = main
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
    case none, abbott, miaomiao
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none:     return "Any"
        case .abbott:   return Libre.name
        case .miaomiao: return MiaoMiao.name
        }
    }
    var type: AnyClass {
        switch self {
        case .none:     return Transmitter.self
        case .abbott:   return Libre.self
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


class Libre: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.abbott) }
    override class var name: String { "Libre" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case abbottCustom     = "FDE3"
        case bleLogin         = "F001"
        case compositeRawData = "F002"

        var description: String {
            switch self {
            case .abbottCustom:     return "Abbott custom"
            case .bleLogin:         return "BLE login"
            case .compositeRawData: return "composite raw data"
            }
        }
    }

    override class var knownUUIDs: [String] { UUID.allCases.map{$0.rawValue} }

    override class var dataServiceUUID: String { UUID.abbottCustom.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.bleLogin.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.compositeRawData.rawValue }


    override func read(_ data: Data, for uuid: String) {

        switch UUID(rawValue: uuid) {

        case .compositeRawData:
            if sensor == nil {
                sensor = Sensor(transmitter: self)
                main.app.sensor = sensor
            }
            if buffer.count == 0 { sensor!.lastReadingDate = main.app.lastReadingDate }
            buffer.append(data)
            main.log("\(name): partial buffer size: \(buffer.count)")

            if buffer.count > (28 + 10 + 8) && data.count == 8 { buffer = Data(data.suffix(46)) }

            if buffer.count == 46 {
                let bleGlucose = parseBLEData(Data(try! Libre2.decryptBLE(id: sensor!.uid, data: buffer)))
                main.log("BLE raw values: \(bleGlucose.map{$0.raw})")

                let trend = bleGlucose[0...6].map { factoryGlucose(raw: $0, calibrationInfo: main.settings.activeSensorCalibrationInfo) }
                let history = bleGlucose[7...9].map { factoryGlucose(raw: $0, calibrationInfo: main.settings.activeSensorCalibrationInfo) }
                main.log("BLE trend: \(trend.map{$0.value})")
                main.log("BLE history: \(history.map{$0.value})")
                main.log("BLE temperatures: \((trend + history).map{Double(String(format: "%.1f", $0.temperature))!})")

                if trend[0].raw > 0 { sensor!.currentGlucose = trend[0].value }

                var rawTrend = [Glucose](main.history.rawTrend)
                let rawTrendIds = rawTrend.map { $0.id }
                rawTrend += bleGlucose.prefix(7).filter { !rawTrendIds.contains($0.id) }
                rawTrend = [Glucose](rawTrend.sorted(by: { $0.id > $1.id }).prefix(16))
                main.history.rawTrend = rawTrend
                main.history.factoryTrend = rawTrend.map { factoryGlucose(raw: $0, calibrationInfo: main.settings.activeSensorCalibrationInfo) }
                main.log("BLE merged trend: \(main.history.factoryTrend.map{$0.value})")

                var rawValues = [Glucose](main.history.rawValues)
                let rawValuesIds = rawValues.map { $0.id }
                rawValues += bleGlucose.suffix(3).filter { !rawValuesIds.contains($0.id) }
                rawValues = [Glucose](rawValues.sorted(by: { $0.id > $1.id }).prefix(32))
                main.history.rawValues = rawValues
                main.history.factoryValues = rawValues.map { factoryGlucose(raw: $0, calibrationInfo: main.settings.activeSensorCalibrationInfo) }
                main.log("BLE merged history: \(main.history.factoryValues.map{$0.value})")

                // TODO: backfill all the latest 8 hours

                main.status("\(sensor!.type)  +  BLE")
            }

        default:
            break
        }
    }


    func parseBLEData( _ data: Data) -> [Glucose] {

        var bleGlucose: [Glucose] = []
        let wearTimeMinutes = UInt16(data[40...41])
        if sensor!.state == .unknown { sensor!.state = .active }
        if sensor!.age == 0 {sensor!.age = Int(wearTimeMinutes) }
        let startDate = sensor!.lastReadingDate - Double(wearTimeMinutes) * 60
        let delay = 2
        for i in 0 ..< 10 {
            let raw = readBits(data, i * 4, 0, 0xe)
            let rawTemperature = readBits(data, i * 4, 0xe, 0xc) << 2
            var temperatureAdjustment = readBits(data, i * 4, 0x1a, 0x5) << 2
            let negativeAdjustment = readBits(data, i * 4, 0x1f, 0x1)
            if negativeAdjustment != 0 {
                temperatureAdjustment = -temperatureAdjustment
            }

            var id = Int(wearTimeMinutes)

            if i < 7 {
                // sparse trend values
                id -= [0, 2, 4, 6, 7, 12, 15][i]

            } else {
                // TODO: precise id of the last three recent historic values
                id = ((id - delay) / 15) * 15 - 15 * (i - 7)
            }

            let date = startDate + Double(id * 60)
            let glucose = Glucose(raw: raw,
                                  rawTemperature: rawTemperature,
                                  temperatureAdjustment: temperatureAdjustment,
                                  id: id,
                                  date: date)
            bleGlucose.append(glucose)
        }
        let crc = UInt16(data[42], data[43])
        main.debugLog("Bluetooth: received BLE data 0x\(data.hex) (wear time: \(wearTimeMinutes) minutes (0x\(String(format: "%04x", wearTimeMinutes))), CRC: \(String(format: "%04x", crc)), computed CRC: \(String(format: "%04x", crc16(Data(data[0...41]))))), glucose values: \(bleGlucose)")
        return bleGlucose
    }

}


class MiaoMiao: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.miaomiao) }
    override class var name: String { "MiaoMiao" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data      = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataWrite = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataRead  = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

        var description: String {
            switch self {
            case .data:      return "data"
            case .dataWrite: return "data write"
            case .dataRead:  return "data read"
            }
        }
    }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }

    enum ResponseType: UInt8, CustomStringConvertible {
        case dataPacket = 0x28
        case newSensor  = 0x32
        case noSensor   = 0x34
        case frequencyChange = 0xD1

        var description: String {
            switch self {
            case .dataPacket:      return "data packet"
            case .newSensor:       return "new sensor"
            case .noSensor:        return "no sensor"
            case .frequencyChange: return "frequency change"
            }
        }
    }

    override init(peripheral: CBPeripheral?, main: MainDelegate) {
        super.init(peripheral: peripheral!, main: main)
        if let peripheral = peripheral, peripheral.name!.contains("miaomiao2") {
            name += " 2"
        }
    }

    override func readCommand(interval: Int = 5) -> [UInt8] {
        var command = [UInt8(0xF0)]
        if [1, 3].contains(interval) {
            command.insert(contentsOf: [0xD1, UInt8(interval)], at: 0)
        }
        return command
    }

    override func parseManufacturerData(_ data: Data) {
        if data.count >= 8 {
            macAddress = data.suffix(6)
            main.log("\(Self.name): MAC Address: \(macAddress.hexAddress))")
        }
    }

    override func read(_ data: Data, for uuid: String) {

        // https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/Models/Tomato.java
        // https://github.com/UPetersen/LibreMonitor/blob/Swift4/LibreMonitor/Bluetooth/MiaoMiaoManager.swift
        // https://github.com/gshaviv/ninety-two/blob/master/WoofWoof/MiaoMiao.swift

        let response = ResponseType(rawValue: data[0])
        if buffer.count == 0 {
            main.log("\(name) response: \(response?.description ?? "unknown") (0x\(data[0...0].hex))")
        }
        if data.count == 1 {
            if response == .noSensor {
                main.status("\(name): no sensor")
            }
            // TODO: prompt the user and allow writing the command 0xD301 to change sensor
            if response == .newSensor {
                main.status("\(name): detected a new sensor")
            }
        } else if data.count == 2 {
            if response == .frequencyChange {
                if data[1] == 0x01 {
                    main.log("\(name): success changing frequency")
                } else {
                    main.log("\(name): failed to change frequency")
                }
            }
        } else {
            if sensor == nil {
                sensor = Sensor(transmitter: self)
                main.app.sensor = sensor
            }
            if buffer.count == 0 { sensor!.lastReadingDate = main.app.lastReadingDate }
            buffer.append(data)
            main.log("\(name): partial buffer size: \(buffer.count)")
            if buffer.count >= 363 {
                main.log("\(name): data size: \(Int(buffer[1]) << 8 + Int(buffer[2]))")

                battery = Int(buffer[13])
                firmware = buffer[14...15].hex
                hardware = buffer[16...17].hex
                main.log("\(name): battery: \(battery), firmware: \(firmware), hardware: \(hardware)")

                sensor!.age = Int(buffer[3]) << 8 + Int(buffer[4])
                sensor!.uid = Data(buffer[5...12])
                main.log("\(name): sensor age: \(sensor!.age) minutes (\(String(format: "%.1f", Double(sensor!.age)/60/24)) days), patch uid: \(sensor!.uid.hex), serial number: \(sensor!.serial)")

                if buffer.count >= 369 {
                    sensor!.patchInfo = Data(buffer[363...368])
                    main.log("\(name): patch info: \(sensor!.patchInfo.hex) (sensor type: \(sensor!.type.rawValue))")
                } else {
                    // https://github.com/dabear/LibreOOPAlgorithm/blob/master/app/src/main/java/com/hg4/oopalgorithm/oopalgorithm/AlgorithmRunner.java
                    sensor!.patchInfo = Data([0xDF, 0x00, 0x00, 0x01, 0x01, 0x02])
                }
                sensor!.fram = Data(buffer[18 ..< 362])
                main.status("\(sensor!.type)  +  \(name)")
            }
        }
    }
}
