import Foundation
import CoreBluetooth


class BluetoothDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    var main: MainDelegate!
    var centralManager: CBCentralManager { main.centralManager }
    var app: AppState { main.app }
    var settings: Settings { main.settings }


    func log(_ text: String) {
        if main != nil { main.log(text) }
    }


    public func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        switch manager.state {
        case .poweredOff:
            log("Bluetooth: state: powered off")
            main.errorStatus("Bluetooth powered off")
            if app.device != nil {
                centralManager.cancelPeripheralConnection(app.device.peripheral!)
                app.device.state = .disconnected
            }
            app.deviceState = "Disconnected"
        case .poweredOn:
            log("Bluetooth: state: powered on")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            main.status("Scanning...")
        case .resetting:    log("Bluetooth: state: resetting")
        case .unauthorized: log("Bluetooth: state: unauthorized")
        case .unknown:      log("Bluetooth: state: unknown")
        case .unsupported:  log("Bluetooth: state: unsupported")
        @unknown default:
            log("Bluetooth: state: unknown")
        }
    }


    public func centralManager(_ manager: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData advertisement: [String : Any], rssi: NSNumber) {
        var name = peripheral.name
        let manufacturerData = advertisement["kCBAdvDataManufacturerData"] as? Data

        var didFindATransmitter = false

        if let name = name {
            for transmitterType in TransmitterType.allCases {
                if name.matches(transmitterType.id) {
                    didFindATransmitter = true
                    if settings.preferredTransmitter != .none && transmitterType != settings.preferredTransmitter {
                        didFindATransmitter = false
                    }
                }
            }
        }

        var companyId = BLE.companies.count - 1 // "< Unknown >"
        if let manufacturerData = manufacturerData {
            companyId = Int(manufacturerData[0]) + Int(manufacturerData[1]) << 8
            if companyId >= BLE.companies.count { companyId = BLE.companies.count - 1 }    // when 0xFFFF
        }

        if name == nil {
            name = "an unnamed peripheral"
            if BLE.companies[companyId].name != "< Unknown >" {
                name = "\(BLE.companies[companyId].name)'s unnamed peripheral"
            }
        }

        if (didFindATransmitter && !settings.preferredDevicePattern.isEmpty && !name!.matches(settings.preferredDevicePattern))
            || !didFindATransmitter && (settings.preferredTransmitter != .none || (!settings.preferredDevicePattern.isEmpty && !name!.matches(settings.preferredDevicePattern))) {
            var scanningFor = "Scanning"
            if !settings.preferredDevicePattern.isEmpty {
                scanningFor += " for '\(settings.preferredDevicePattern)'"
            }
            main.status("\(scanningFor)...\nSkipping \(name!)...")
            log("Bluetooth: \(scanningFor.lowercased()), skipping \(name!)")

            return
        }

        centralManager.stopScan()
        if name!.lowercased().hasPrefix("abbott") {
            app.transmitter = Abbott(peripheral: peripheral, main: main)
            app.device = app.transmitter
            app.device.name = "Libre 2"
        } else if name!.lowercased().hasPrefix("blu") {
            app.transmitter = BluCon(peripheral: peripheral, main: main)
            app.device = app.transmitter
        } else if name! == "Bubble" {
            app.transmitter = Bubble(peripheral: peripheral, main: main)
            app.device = app.transmitter
        } else if name!.matches("miaomiao") {
            app.transmitter = MiaoMiao(peripheral: peripheral, main: main)
            app.device = app.transmitter

            // } else if name.matches("custom") {
            //    custom = Custom(peripheral: peripheral, main: main)
            //    app.device = custom
            //    app.device.name = peripheral.name!
            //    app.transmitter = custom.transmitter
            //    app.transmitter.name = "bridge"

        } else if name!.matches("Mi Smart Band") {
            app.device = Device(peripheral: peripheral, main: main)
            app.device.name = name!
            if manufacturerData!.count >= 8 {
                app.device.macAddress = Data(manufacturerData!.suffix(6))
                log("Bluetooth: \(name!) MAC Address: \(app.device.macAddress.hex.uppercased())")
            }

        } else {
            app.device = Device(peripheral: peripheral, main: main)
            app.device.name = name!
        }

        app.device.rssi = Int(truncating: rssi)
        app.device.company = BLE.companies[companyId].name
        var msg = "Bluetooth: found \(name!): RSSI: \(rssi), advertised data: \(advertisement)"
        if app.device.company == "< Unknown >" {
            if companyId != BLE.companies.count - 1 {
                msg += ", company id: \(companyId) (0x\(String(format: "%04x", companyId)), unknown)"
            }
        }
        else {
            msg += ", company: \(app.device.company) (id: 0x\(String(format: "%04x", companyId)))"
        }
        log(msg)
        if let manufacturerData = manufacturerData {
            app.device.parseManufacturerData(manufacturerData)
        }
        main.status("\(app.device.name)")
        app.device.peripheral?.delegate = self
        main.log("Bluetooth: connecting to \(name!)...")
        centralManager.connect(app.device.peripheral!, options: nil)
        if app.device.state == .connecting { app.deviceState = "Connecting" }
    }


    public func centralManager(_ manager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = peripheral.name ?? "an unnamed peripheral"
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
        let name = peripheral.name ?? "unnamed peripheral"
        app.device.state = peripheral.state
        if let services = peripheral.services {
            for service in services {
                let serviceUUID = service.uuid.uuidString
                var description = "unknown service"
                if serviceUUID == type(of: app.device).dataServiceUUID {
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
        if serviceUUID == type(of: app.device).dataServiceUUID {
            serviceDescription = "data"
        }

        for characteristic in characteristics {
            let uuid = characteristic.uuid.uuidString
            app.device.characteristics[uuid] = characteristic

            var msg = "Bluetooth: discovered \(app.device.name) \(serviceDescription) service's characteristic \(uuid)"
            msg += (", properties: \(characteristic.properties)")

            if uuid == BluCon.dataReadCharacteristicUUID || uuid == Bubble.dataReadCharacteristicUUID || uuid == MiaoMiao.dataReadCharacteristicUUID {
                app.device.readCharacteristic = characteristic
                app.device.peripheral?.setNotifyValue(true, for: app.device.readCharacteristic!)
                msg += " (data read)"

            } else if uuid == BluCon.dataWriteCharacteristicUUID || uuid == Bubble.dataWriteCharacteristicUUID || uuid == MiaoMiao.dataWriteCharacteristicUUID {
                msg += " (data write)"
                app.device.writeCharacteristic = characteristic

            } else if let uuid = Abbott.UUID(rawValue: uuid) {
                msg += " (\(uuid))"
                if characteristic.properties.contains(.notify) {
                    app.device.peripheral?.setNotifyValue(true, for: characteristic)
                }
                if characteristic.properties.contains(.read) {
                    app.device.peripheral?.readValue(for: characteristic)
                    msg += "; reading it"
                }

                // } else if let uuid = Custom.UUID(rawValue: uuid) {
                //    msg += " (\(uuid))"
                //    if uuid.description.contains("unknown") {
                //        if characteristic.properties.contains(.notify) {
                //            app.device.peripheral?.setNotifyValue(true, for: characteristic)
                //        }
                //        if characteristic.properties.contains(.read) {
                //            app.device.peripheral?.readValue(for: characteristic)
                //            msg += "; reading it"
                //        }
                //    }

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
            // app.device.write([0x00, 0x01, 0x05])
            // log("Bubble: writing reset and send data every 5 minutes command 0x000105")
        }

        if app.device.type == .transmitter(.miaomiao) && serviceUUID == MiaoMiao.dataServiceUUID {
            let readCommand = app.device.readCommand(interval: settings.readingInterval)
            app.device.write(readCommand)
            log("\(app.device.name): writing start reading command 0x\(Data(readCommand).hex)")
            // app.device.write([0xD3, 0x01]); log("MiaoMiao: writing start new sensor command D301")
        }

    }


    public func centralManager(_ manager: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? "an unnamed peripheral"
        app.device.state = peripheral.state
        log("Bluetooth: \(name) has disconnected.")
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

    public func centralManager(_ manager: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? "an unnamed peripheral"
        var msg = "Bluetooth: failed to connect to \(name)"
        var errorCode: CBError.Code?

        if let error = error {
            errorCode = CBError.Code(rawValue: (error as NSError).code)
            msg += ", error type \(errorCode!.rawValue): \(error.localizedDescription)"
        }

        if let errorCode = errorCode, errorCode.rawValue == 14 { // Peer removed pairing information (BluCon)
            main.errorStatus("Failed to connect: \(error!.localizedDescription)")
        } else {
            msg += "; retrying..."
            main.errorStatus("Failed to connect, retrying...")
            centralManager.connect(app.device.peripheral!, options: nil)
        }

        log(msg)
    }


    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let name = peripheral.name ?? "an unnamed peripheral"
        var characteristicString = characteristic.uuid.uuidString
        if error != nil {
            log("Bluetooth: error while writing \(name)'s \(characteristicString) characteristic value: \(error!.localizedDescription)")
        } else {
            if [BluCon.dataWriteCharacteristicUUID, Bubble.dataWriteCharacteristicUUID, MiaoMiao.dataWriteCharacteristicUUID].contains(characteristicString) {
                characteristicString = "data write"
            }
            log("Bluetooth: \(name) did write value for \(characteristicString) characteristic")
        }
    }


    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let name = peripheral.name ?? "an unnamed peripheral"
        var characteristicString = characteristic.uuid.uuidString
        if [BluCon.dataReadCharacteristicUUID, Bubble.dataReadCharacteristicUUID, MiaoMiao.dataReadCharacteristicUUID].contains(characteristicString) {
            characteristicString = "data read"
        }
        log("Bluetooth: \(name) did update notification state for \(characteristicString) characteristic")
    }


    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let name = peripheral.name ?? "an unnamed peripheral"
        var characteristicString = characteristic.uuid.uuidString
        if [BluCon.dataReadCharacteristicUUID, Bubble.dataReadCharacteristicUUID, MiaoMiao.dataReadCharacteristicUUID].contains(characteristicString) {
            characteristicString = "data read"
        }

        guard let data = characteristic.value
        else { log("Bluetooth: \(name)'s error updating value for \(characteristicString) characteristic: \(error!.localizedDescription)"); return }

        var msg = "Bluetooth: \(name) did update value for \(characteristicString) characteristic (\(data.count) bytes received):"
        if data.count > 0 {
            msg += " hex: \(data.hex),"
        }

        if let uuid = BLE.UUID(rawValue: characteristic.uuid.uuidString) {

            log("\(msg) \(uuid): \(uuid != .batteryLevel ? "\"\(data.string)\"" : String(Int(data[0])))")

            switch uuid {

            case .batteryLevel:
                app.device.battery = Int(data[0])
            case .model:
                app.device.model = data.string
                if app.device.peripheral?.name == nil {
                    app.device.name = app.device.model
                    main.status(app.device.name)
                }
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
            log("\(msg) string: \"\(data.string)\"")

            app.lastReadingDate = Date()

            app.device.read(data, for: characteristic.uuid.uuidString)

            if app.device.type == .transmitter(.blu) || app.device.type == .transmitter(.bubble) || app.device.type == .transmitter(.miaomiao) {
                var headerLength = 0
                if app.device.type == .transmitter(.miaomiao) && characteristic.uuid.uuidString == MiaoMiao.dataReadCharacteristicUUID {
                    headerLength = 18 + 1
                }
                if let sensor = app.transmitter.sensor, sensor.fram.count > 0, app.transmitter.buffer.count >= (sensor.fram.count + headerLength) {
                    main.parseSensorData(sensor)
                    app.transmitter.buffer = Data()
                }
            } else if app.transmitter?.sensor != nil {
                main.didParseSensor(app.transmitter.sensor!)
            }
        }
    }
}
