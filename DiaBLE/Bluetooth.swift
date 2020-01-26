import Foundation
import CoreBluetooth


class BLE {

    static let knownDevices: [Device.Type] = DeviceType.allCases.map { ($0.type as! Device.Type) }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        
        case device       = "180A"
        case model        = "2A24"
        case serial       = "2A25"
        case firmware     = "2A26"
        case hardware     = "2A27"
        case software     = "2A28"
        case manufacturer = "2A29"

        case battery      = "180F"
        case batteryLevel = "2A19"

        case time         = "1805"
        case currentTime  = "2A2B"

        case dfu          = "FE59"

        var description: String {
            switch self {
            case .device:       return "device information"
            case .model:        return "model number"
            case .serial:       return "serial number"
            case .firmware:     return "firmware version"
            case .hardware:     return "hardware version"
            case .software:     return "software version"
            case .manufacturer: return "manufacturer"
            case .battery:      return "battery"
            case .batteryLevel: return "battery level"
            case .time:         return "time"
            case .currentTime:  return "current time"
            case .dfu:          return "device firmware update"
            }
        }
    }
}


extension CBCharacteristicProperties: CustomStringConvertible {
    public var description: String {
        var d = [String: Bool]()
        d["Broadcast"] = self.contains(.broadcast)
        d["Read"] = self.contains(.read)
        d["WriteWithoutResponse"] = self.contains(.writeWithoutResponse)
        d["Write"] = self.contains(.write)
        d["Notify"] = self.contains(.notify)
        d["Indicate"] = self.contains(.indicate)
        d["AuthenticatedSignedWrites"] = self.contains(.authenticatedSignedWrites)
        d["ExtendedProperties"] = self.contains(.extendedProperties)
        d["NotifyEncryptionRequired"] = self.contains(.notifyEncryptionRequired)
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
        case .transmitter(let type): return type.rawValue
        case .watch(let type):       return type.rawValue
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


class Device {

    class var type: DeviceType { DeviceType.none }
    class var name: String { "Unknown" }

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
    var firmware: String = ""
    var hardware: String = ""
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
    convenience init(battery: Int, firmware: String = "", hardware: String = "", macAddress: Data = Data()) {
        self.init()
        self.battery = battery
        self.firmware = firmware
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
        if main.settings.debugLevel > 0 { main.log("\(name): requested value for \(uuid)") }
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
            if app.transmitter != nil {
                centralManager.cancelPeripheralConnection(app.transmitter.peripheral!)
                app.transmitter.state = .disconnected
            }
            app.transmitterState = "Disconnected"
        case .poweredOn:
            log("Bluetooth state: Powered on")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
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

        if name.lowercased().contains("wat") { // Hopefully people don't rename their watch device name...
            for watchType in WatchType.allCases {
                if name.lowercased().contains(watchType.rawValue) {
                    found = true // found a watch different than the Apple Watch
                }
                if settings.preferredWatch == .none || settings.preferredWatch == .appleWatch {
                    found = true // it is an Apple Watch and the user didn't choose another one
                }
            }
        }
        if found == true && settings.preferredTransmitter != .none  {
            found = false
        }
        for transmitterType in TransmitterType.allCases {
            if name.lowercased().contains(transmitterType.rawValue) {
                found = true
                if settings.preferredTransmitter != .none && transmitterType != settings.preferredTransmitter {
                    found = false
                }
                if settings.preferredWatch != .none {
                    found = false
                }
            }
        }

        if (found && !settings.preferredDevicePattern.isEmpty && !name.contains(settings.preferredDevicePattern))
            || !found && (settings.preferredTransmitter != .none || settings.preferredWatch != .none || (!settings.preferredDevicePattern.isEmpty && !name.lowercased().contains(settings.preferredDevicePattern.lowercased()))) {
            log("Bluetooth: skipping \"\(name)\" service")
            return
        }

        log("Bluetooth: found \"\(name)\" (RSSI: \(rssi), advertised data: \(advertisement)); connecting to it")
        centralManager.stopScan()

        if name == "Bubble" {
            app.transmitter = Bubble(peripheral: peripheral, main: main)
        } else if name.contains("miaomiao") {
            app.transmitter = MiaoMiao(peripheral: peripheral, main: main)
        } else if name.lowercased().contains("wat") {
            if name.hasPrefix("Watlaa") {
                app.watch = Watlaa(peripheral: peripheral, main: main)
            } else {
                app.watch = AppleWatch(peripheral: peripheral, main: main)
            }
            app.transmitter = app.watch
        } else {
            app.transmitter = Transmitter(peripheral: peripheral, main: main)
            app.transmitter.name = name
        }

        if let manifacturerData = advertisement["kCBAdvDataManufacturerData"] as? Data {
            if app.transmitter.type == .transmitter(.bubble) {
                let transmitterData = Data(manifacturerData.suffix(4))
                let firmware = "\(Int(transmitterData[0])).\(Int(transmitterData[1]))"
                let hardware = "\(Int(transmitterData[2])).\(Int(transmitterData[3]))"
                let macAddress = Data(manifacturerData[2...7])
                log("Bluetooth: \(Bubble.name)'s advertised manufacturer data: firmware: \(firmware), hardware: \(hardware), MAC address: \(macAddress.hexAddress)" )
                app.transmitter.macAddress = macAddress
            } else {
                log("Bluetooth: \(name)'s advertised manufacturer data: \(manifacturerData.hex)" )
            }
        }

        main.info("\n\n\(app.transmitter.name)")
        app.transmitter.peripheral?.delegate = self
        centralManager.connect(app.transmitter.peripheral!, options: nil)
    }


    public func centralManager(_ manager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = peripheral.name ?? "An unnamed peripheral"
        var msg = "Bluetooth: \(name) has connected"
        if app.transmitter.state == .disconnected {
            app.transmitter.state = peripheral.state
            app.transmitterState = "Connected"
            msg += ("; discovering services")
            peripheral.discoverServices(nil)
        }
        log(msg)
    }


    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        app.transmitter.state = peripheral.state
        if let services = peripheral.services {
            for service in services {
                let serviceUUID = service.uuid.uuidString
                var description = "unknown service"
                if serviceUUID == type(of:app.transmitter).dataServiceUUID {
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
        if serviceUUID == type(of:app.transmitter).dataServiceUUID {
            serviceDescription = "data"
        }

        for characteristic in characteristics {
            let uuid = characteristic.uuid.uuidString
            var msg = "Bluetooth: discovered \(app.transmitter.name) \(serviceDescription) service's characteristic \(uuid)"
            msg += (", properties: \(characteristic.properties)")

            if uuid == Bubble.dataReadCharacteristicUUID || uuid == MiaoMiao.dataReadCharacteristicUUID || uuid == Watlaa.dataReadCharacteristicUUID {
                app.transmitter.readCharacteristic = characteristic
                app.transmitter.peripheral?.setNotifyValue(true, for: app.transmitter.readCharacteristic!)
                msg += " (data read)"

            } else if uuid == Bubble.dataWriteCharacteristicUUID || uuid == MiaoMiao.dataWriteCharacteristicUUID {
                msg += " (data write)"
                app.transmitter.writeCharacteristic = characteristic

            } else if let uuid = Watlaa.UUID(rawValue: uuid) {
                msg += " (\(uuid))"

                // } else if let uuid = OtherDevice.UUID(rawValue: uuid) {
                //    msg += " (\(uuid))"
            }


            app.transmitter.characteristics[uuid] = characteristic

            if let uuid = BLE.UUID(rawValue: uuid) {
                if uuid == .batteryLevel {
                    app.transmitter.peripheral?.setNotifyValue(true, for: characteristic)
                }
                app.transmitter.peripheral?.readValue(for: characteristic)
                msg += " (\(uuid)); reading it"
            }

            log(msg)
        }

        if app.transmitter.type == .transmitter(.bubble) && serviceUUID == Bubble.dataServiceUUID {
            let readCommand = app.transmitter.readCommand(interval: settings.readingInterval)
            app.transmitter.write(readCommand)
            log("Bubble: writing start reading command 0x\(Data(readCommand).hex)")
            // bubble!.write([0x00, 0x01, 0x05])
            // log("Bubble: writing reset and send data every 5 minutes command 0x000105")
        }

        if app.transmitter.type == .transmitter(.miaomiao) && serviceUUID == MiaoMiao.dataServiceUUID {
            let readCommand = app.transmitter.readCommand(interval: settings.readingInterval)
            app.transmitter.write(readCommand)
            log("MiaoMiao: writing start reading command 0x\(Data(readCommand).hex)")
            // app.transmitter.write([0xD3, 0x01]); log("MiaoMiao writing start new sensor command D301")
        }

        if app.transmitter.type == .watch(.watlaa) && serviceUUID == Watlaa.dataServiceUUID {
            (app.transmitter as! Watlaa).readSetup()
            log("Watlaa: reading data")
        }
    }


    public func centralManager(_ manager: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        app.transmitter.state = peripheral.state
        log("\(name) has disconnected.")
        if error != nil {
            let errorCode = CBError.Code(rawValue: (error! as NSError).code)! // 6 = timed out when out of range
            log("Bluetooth error type \(errorCode.rawValue): \(error!.localizedDescription)")
            if app.transmitter != nil && (settings.preferredTransmitter == .none || settings.preferredTransmitter.id == app.transmitter.type.id) {
                centralManager.connect(peripheral, options: nil)
            }
        }
        app.transmitterState = "Disconnected"
    }


    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let name = peripheral.name ?? "Unnamed peripheral"
        if error != nil {
            log("Error while writing \(name) characteristic \(characteristic.uuid.uuidString) value: \(error!.localizedDescription)")
        } else {
            log("\(name) did write characteristic value for \(characteristic.uuid.uuidString)")
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
            else { log("\(name): missing updated value for \(characteristicString) characteristic"); return }

        let msg = "\(name) did update value for \(characteristicString) characteristic (\(data.count) bytes received):"

        if let uuid = BLE.UUID(rawValue: characteristic.uuid.uuidString) {

            log("\(msg) \(uuid): \(uuid != .batteryLevel ? data.string : String(Int(data[0]))) ")

            switch uuid {

            case .batteryLevel:
                app.transmitter.battery = Int(data[0])
            case .model:
                app.transmitter.hardware += "\n\(data.string)"
            case .firmware:
                app.transmitter.firmware = data.string
            case .hardware:
                app.transmitter.hardware += " \(data.string)"
            case .manufacturer:
                app.transmitter.hardware = data.string

            case .serial, .software:
                break

            default:
                break
            }

        } else {
            log("\(msg) string: \"\(data.string)\", hex: \(data.hex)")

            app.lastReadingDate = Date()

            app.transmitter.read(data, for: characteristic.uuid.uuidString)

            if app.transmitter.type == .transmitter(.bubble) || app.transmitter.type == .transmitter(.miaomiao) || app.transmitter.type == .watch(.watlaa) {
                if let sensor = app.transmitter.sensor, sensor.fram.count > 0, app.transmitter.buffer.count >=  sensor.fram.count  {
                    main.parseSensorData(sensor)
                    app.transmitter.buffer = Data()
                }
            } else if app.transmitter.sensor != nil {
                main.didParseSensor(app.transmitter.sensor!)
            }
        }
    }
}
