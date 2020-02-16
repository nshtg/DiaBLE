import Foundation
import CoreBluetooth


class BLE {

    static let knownDevices: [Device.Type] = DeviceType.allCases.filter{ $0.id != "none" }.map{ ($0.type as! Device.Type) }
    static let knownDevicesIds: [String]   = DeviceType.allCases.filter{ $0.id != "none" }.map{ $0.id }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        
        case device        = "180A"
        case model         = "2A24"
        case serial        = "2A25"
        case firmware      = "2A26"
        case hardware      = "2A27"
        case software      = "2A28"
        case manufacturer  = "2A29"

        case battery       = "180F"
        case batteryLevel  = "2A19"

        case time          = "1805"
        case currentTime   = "2A2B"
        case localTimeInfo = "2A0F"

        case dfu           = "FE59"

        var description: String {
            switch self {
            case .device:        return "device information"
            case .model:         return "model number"
            case .serial:        return "serial number"
            case .firmware:      return "firmware version"
            case .hardware:      return "hardware version"
            case .software:      return "software version"
            case .manufacturer:  return "manufacturer"
            case .battery:       return "battery"
            case .batteryLevel:  return "battery level"
            case .time:          return "time"
            case .currentTime:   return "current time"
            case .localTimeInfo: return "local timne information"
            case .dfu:           return "device firmware update"
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
    var state: CBPeripheralState = .disconnected

    var readCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?

    var battery: Int = -1
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
    convenience init(battery: Int, firmware: String = "", manufacturer: String = "", hardware: String = "", macAddress: Data = Data()) {
        self.init()
        self.battery = battery
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

    /// varying ireading interval
    func readCommand(interval: Int = 5) -> [UInt8] { [] }

    func parseManufacturerData(_ data: Data) {
        main.log("Bluetooth: \(name)'s advertised manufacturer data: \(data.hex)" )
    }

}


class BluetoothDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    var main: MainDelegate!
    var centralManager: CBCentralManager { main.centralManager }
    var app: App { main.app }
    var settings: Settings { main.settings }


    func log(_ text: String) {
        if main != nil { main.log(text) }
    }


    public func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        switch manager.state {
        case .poweredOff:
            log("Bluetooth state: Powered off")
            if app.device != nil {
                centralManager.cancelPeripheralConnection(app.device.peripheral!)
                app.device.state = .disconnected
            }
            app.deviceState = "Disconnected"
        case .poweredOn:
            log("Bluetooth state: Powered on")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            main.info("\n\nScanning...")
        case .resetting:    log("Bluetooth state: Resetting")
        case .unauthorized: log("Bluetooth state: Unauthorized")
        case .unknown:      log("Bluetooth state: Unknown")
        case .unsupported:  log("Bluetooth state: Unsupported")
        @unknown default:
            log("Bluetooth state: Unknown")
        }
    }


    public func centralManager(_ manager: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData advertisement: [String : Any], rssi: NSNumber) {
        let name = peripheral.name ?? "Unnamed peripheral"

        var found = false

        if name.matches("wat") { // Found a watch: hopefully people don't rename their watch device name...
            for var watchType in WatchType.allCases {
                if name.matches(watchType.id) {
                    found = true // found a watch different than the Apple Watch
                }
                if settings.preferredWatch == .none || settings.preferredWatch == .appleWatch {
                    found = true // it is an Apple Watch and the user didn't choose another one
                    watchType = .appleWatch
                }
                if settings.preferredWatch != .none && watchType != settings.preferredWatch {
                    found = false
                }
            }
        }
        if found == true && settings.preferredTransmitter != .none  {
            found = false
        }
        for transmitterType in TransmitterType.allCases {
            if name.matches(transmitterType.id) {
                found = true
                if settings.preferredTransmitter != .none && transmitterType != settings.preferredTransmitter {
                    found = false
                }
                if settings.preferredWatch != .none {
                    found = false
                }
            }
        }

        if (found && !settings.preferredDevicePattern.isEmpty && !name.matches(settings.preferredDevicePattern))
            || !found && (settings.preferredTransmitter != .none || settings.preferredWatch != .none || (!settings.preferredDevicePattern.isEmpty && !name.matches(settings.preferredDevicePattern))) {
            var scanningFor = "Scanning"
            if !settings.preferredDevicePattern.isEmpty {
                scanningFor += " for '\(settings.preferredDevicePattern)'"
            }
            main.info("\n\n\(scanningFor)...\nSkipping \(name)...")
            log("Bluetooth: \(scanningFor.lowercased()), skipping \"\(name)\" service")
            return
        }

        log("Bluetooth: found \"\(name)\" (RSSI: \(rssi), advertised data: \(advertisement)); connecting to it")
        centralManager.stopScan()

        if name == "Bubble" {
            app.transmitter = Bubble(peripheral: peripheral, main: main)
            app.device = app.transmitter
        } else if name.matches("miaomiao") {
            app.transmitter = MiaoMiao(peripheral: peripheral, main: main)
            app.device = app.transmitter
        } else if name.matches("wat") {
            if name.hasPrefix("Watlaa") {
                app.watch = Watlaa(peripheral: peripheral, main: main)
            } else {
                app.watch = AppleWatch(peripheral: peripheral, main: main)
            }
            app.device = app.watch
            app.device.name = peripheral.name!
            app.transmitter = app.watch.transmitter
            app.transmitter.name = "bridge"

        } else {
            app.device = Device(peripheral: peripheral, main: main)
            app.device.name = name
        }

        if let manufacturerData = advertisement["kCBAdvDataManufacturerData"] as? Data {
            app.device.parseManufacturerData(manufacturerData)
        }

        main.info("\n\n\(app.device.name)")
        app.device.peripheral?.delegate = self
        centralManager.connect(app.device.peripheral!, options: nil)
    }


    public func centralManager(_ manager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = peripheral.name ?? "An unnamed peripheral"
        var msg = "Bluetooth: \(name) has connected"
        if app.device.state == .disconnected {
            app.device.state = peripheral.state
            app.deviceState = "Connected"
            msg += ("; discovering services")
            peripheral.discoverServices(nil)
        }
        log(msg)
    }


    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        app.device.state = peripheral.state
        if let services = peripheral.services {
            for service in services {
                let serviceUUID = service.uuid.uuidString
                var description = "unknown service"
                if serviceUUID == type(of:app.device).dataServiceUUID {
                    description = "data service"
                }
                if let uuid = BLE.UUID(rawValue: serviceUUID) {
                    description = uuid.description
                }
                log("Bluetooth: discovered \(name)'s service \(serviceUUID) (\(description)); discovering characteristics")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics
            else { log("Bluetooth: unable to retrieve service characteristics"); return }

        let serviceUUID = service.uuid.uuidString
        var serviceDescription = serviceUUID
        if serviceUUID == type(of:app.device).dataServiceUUID {
            serviceDescription = "data"
        }

        for characteristic in characteristics {
            let uuid = characteristic.uuid.uuidString
            app.device.characteristics[uuid] = characteristic

            var msg = "Bluetooth: discovered \(app.device.name) \(serviceDescription) service's characteristic \(uuid)"
            msg += (", properties: \(characteristic.properties)")

            if uuid == Bubble.dataReadCharacteristicUUID || uuid == MiaoMiao.dataReadCharacteristicUUID || uuid == Watlaa.dataReadCharacteristicUUID {
                app.device.readCharacteristic = characteristic
                app.device.peripheral?.setNotifyValue(true, for: app.device.readCharacteristic!)
                msg += " (data read)"

            } else if uuid == Bubble.dataWriteCharacteristicUUID || uuid == MiaoMiao.dataWriteCharacteristicUUID || uuid == Watlaa.dataWriteCharacteristicUUID {
                msg += " (data write)"
                app.device.writeCharacteristic = characteristic

            } else if let uuid = Watlaa.UUID(rawValue: uuid) {
                msg += " (\(uuid))"
                if uuid.description.contains("unknown") {
                    if characteristic.properties.contains(.notify) {
                        app.device.peripheral?.setNotifyValue(true, for: characteristic)
                    }
                    if characteristic.properties.contains(.read) {
                        app.device.peripheral?.readValue(for: characteristic)
                        msg += "; reading it"
                    }
                }

            } else if let uuid = BLE.UUID(rawValue: uuid) {
                if uuid == .batteryLevel {
                    app.device.peripheral?.setNotifyValue(true, for: characteristic)
                }
                app.device.peripheral?.readValue(for: characteristic)
                msg += " (\(uuid)); reading it"

                // } else if let uuid = OtherDevice.UUID(rawValue: uuid) {
                //    msg += " (\(uuid))"

            } else {
                msg += " (unknown)"
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                    msg += "; reading it"
                }
            }

            log(msg)
        }

        if app.device.type == .transmitter(.bubble) && serviceUUID == Bubble.dataServiceUUID {
            let readCommand = app.transmitter.readCommand(interval: settings.readingInterval)
            app.device.write(readCommand)
            log("Bubble: writing start reading command 0x\(Data(readCommand).hex)")
            // bubble!.write([0x00, 0x01, 0x05])
            // log("Bubble: writing reset and send data every 5 minutes command 0x000105")
        }

        if (app.device.type == .transmitter(.miaomiao) || app.device.type == .watch(.watlaa)) && (serviceUUID == MiaoMiao.dataServiceUUID || serviceUUID == Watlaa.dataServiceUUID) {
            let readCommand = app.device.readCommand(interval: settings.readingInterval)
            app.device.write(readCommand)
            log("\(app.device.name): writing start reading command 0x\(Data(readCommand).hex)")
            // app.transmitter.write([0xD3, 0x01]); log("MiaoMiao writing start new sensor command D301")
        }

        if app.device.type == .watch(.watlaa) && serviceUUID == Watlaa.dataServiceUUID {
            (app.device as! Watlaa).readSetup()
            log("Watlaa: reading configuration")
        }
    }


    public func centralManager(_ manager: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        app.device.state = peripheral.state
        log("\(name) has disconnected.")
        app.deviceState = "Disconnected"
        if error != nil {
            let errorCode = CBError.Code(rawValue: (error! as NSError).code)! // 6 = timed out when out of range
            log("Bluetooth: error type \(errorCode.rawValue): \(error!.localizedDescription)")
            if app.transmitter != nil && (settings.preferredTransmitter == .none || settings.preferredTransmitter.id == app.transmitter.type.id) {
                centralManager.connect(peripheral, options: nil)
            } else {
                app.device = nil
                app.transmitter = nil
            }
        } else {
            app.device = nil
            app.transmitter = nil
        }
    }


    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        if error != nil {
            log("Bluetooth: error while writing \(name) characteristic \(characteristic.uuid.uuidString) value: \(error!.localizedDescription)")
        } else {
            log("Bluetooth: \(name) did write characteristic value for \(characteristic.uuid.uuidString)")
        }
    }


    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        var characteristicString = characteristic.uuid.uuidString
        if [Bubble.dataReadCharacteristicUUID, MiaoMiao.dataReadCharacteristicUUID, Watlaa.dataReadCharacteristicUUID].contains(characteristicString) {
            characteristicString = "data read"
        }
        log("Bluetooth: \(name) did update notification state for \(characteristicString) characteristic")
    }


    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        var characteristicString = characteristic.uuid.uuidString
        if [Bubble.dataReadCharacteristicUUID, MiaoMiao.dataReadCharacteristicUUID, Watlaa.dataReadCharacteristicUUID].contains(characteristicString) {
            characteristicString = "data read"
        }

        guard let data = characteristic.value
            else { log("Bluetooth: \(name) missed updating value for \(characteristicString) characteristic"); return }

        let msg = "Bluetooth: \(name) did update value for \(characteristicString) characteristic (\(data.count) bytes received):"

        if let uuid = BLE.UUID(rawValue: characteristic.uuid.uuidString) {

            log("\(msg) \(uuid): \(uuid != .batteryLevel ? data.string : String(Int(data[0]))) ")

            switch uuid {

            case .batteryLevel:
                app.device.battery = Int(data[0])
            case .model:
                app.device.model = data.string
            case .serial:
                app.device.serial = data.string
            case .firmware:
                app.device.firmware = data.string
            case .hardware:
                app.device.hardware += data.string
            case .software:
                app.device.software = data.string
            case .manufacturer:
                app.device.manufacturer = data.string

            default:
                break
            }

        } else {
            log("\(msg) hex: \(data.hex), string: \"\(data.string)")

            app.lastReadingDate = Date()

            app.device.read(data, for: characteristic.uuid.uuidString)

            if app.device.type == .transmitter(.bubble) || app.device.type == .transmitter(.miaomiao) || app.device.type == .watch(.watlaa) {
                var headerLength = 0
                if app.device.type == .transmitter(.miaomiao) || (app.device.type == .watch(.watlaa) && characteristic.uuid.uuidString == MiaoMiao.dataReadCharacteristicUUID) {
                    headerLength = 18 + 1
                }
                if let sensor = app.transmitter.sensor, sensor.fram.count > 0, app.transmitter.buffer.count >= (sensor.fram.count + headerLength) {
                    main.parseSensorData(sensor)
                    app.transmitter.buffer = Data()
                }
            } else if app.transmitter.sensor != nil {
                main.didParseSensor(app.transmitter.sensor!)
            }
        }
    }
}
