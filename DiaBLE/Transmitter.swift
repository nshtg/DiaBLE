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
    var sensor: Sensor?
}


class Bubble: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.bubble) }
    override class var name: String { "Bubble" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data      = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataWrite = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataRead  = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

        var description: String {
            switch self {
            case .data:      return "data"
            case .dataRead:  return "data read"
            case .dataWrite: return "data write"
            }
        }
    }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }

    enum ResponseType: UInt8, CustomStringConvertible {
        case dataInfo =     0x80
        case dataPacket =   0x82
        case noSensor =     0xBF
        case serialNumber = 0xC0
        case patchInfo =    0xC1

        var description: String {
            switch self {
            case .dataInfo:     return "data info"
            case .dataPacket:   return "data packet"
            case .noSensor:     return "no sensor"
            case .serialNumber: return "serial number"
            case .patchInfo:    return "patch info"
            }
        }
    }


    override func readCommand(interval: Int = 5) -> [UInt8] {
        return [0x00, 0x00, UInt8(interval)]
    }


    override func parseManufacturerData(_ data: Data) {
        let transmitterData = Data(data.suffix(4))
        let firmware = "\(Int(transmitterData[0])).\(Int(transmitterData[1]))"
        let hardware = "\(Int(transmitterData[2])).\(Int(transmitterData[3]))"
        let macAddress = Data(data[2...7])
        main.log("\(Self.name): advertised manufacturer data: firmware: \(firmware), hardware: \(hardware), MAC address: \(macAddress.hexAddress)" )
        self.macAddress = macAddress
    }

    
    override func read(_ data: Data, for uuid: String) {

        // https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/Models/Bubble.java

        let response = ResponseType(rawValue: data[0])
        main.log("\(name) response: \(response?.description ?? "unknown") (0x\(data[0...0].hex))")

        if response == .noSensor {
            main.info("\n\n\(name): no sensor")

        } else if response == .dataInfo {
            battery = Int(data[4])
            firmware = "\(data[2]).\(data[3])"
            hardware = "\(data[data.count-2]).\(data[data.count-1])"
            main.log("\(name): battery: \(battery), firmware: \(firmware), hardware: \(hardware)")
            // confirm receipt
            write([0x02, 0x01, 0x00, 0x00, 0x00, 0x2B])

        } else {
            if sensor == nil {
                sensor = Sensor(transmitter: self)
                main.app.sensor = sensor
            }
            if response == .serialNumber {
                sensor!.uid = Data(data[2...9])
                main.log("\(name): patch uid: \(sensor!.uid.hex), serial number: \(sensor!.serial)")

            } else if response == .patchInfo {
                sensor!.patchInfo = Data(Double(firmware)! < 1.35 ? data[3...8] : data[5...10])
                main.log("\(name): patch info: \(sensor!.patchInfo.hex)")

            } else if response == .dataPacket {
                if buffer.count == 0 { sensor!.lastReadingDate = main.app.lastReadingDate }
                buffer.append(data.suffix(from: 4))
                main.log("\(name): partial buffer count: \(buffer.count)")
                if buffer.count == 352 {
                    let fram = buffer[..<344]
                    // let footer = buffer.suffix(8)
                    sensor!.fram = Data(fram)
                    main.info("\n\n\(sensor!.type)  +  \(name)")
                }
            }
        }
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
            case .dataRead:  return "data read"
            case .dataWrite: return "data write"
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
                main.info("\n\n\(name): no sensor")
            }
            // TODO: prompt the user and allow writing the command 0xD301 to change sensor
            if response == .newSensor {
                main.info("\n\n\(name): detected a new sensor")
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
            main.log("\(name): partial buffer count: \(buffer.count)")
            if buffer.count >= 363 {
                main.log("\(name): data count: \(Int(buffer[1]) << 8 + Int(buffer[2]))")

                battery = Int(buffer[13])
                firmware = buffer[14...15].hex
                hardware = buffer[16...17].hex
                main.log("\(name): battery: \(battery), firmware: \(firmware), hardware: \(hardware)")

                sensor!.age = Int(buffer[3]) << 8 + Int(buffer[4])
                sensor!.uid = Data(buffer[5...12])
                main.log("\(name): sensor age: \(sensor!.age) minutes (\(String(format: "%.1f", Double(sensor!.age)/60/24)) days), patch uid: \(sensor!.uid.hex), serial number: \(sensor!.serial)")

                if buffer.count > 363 {
                    sensor!.patchInfo = Data(buffer[363...368])
                    main.log("\(name): patch info: \(sensor!.patchInfo.hex)")
                } else {
                    // https://github.com/dabear/LibreOOPAlgorithm/blob/master/app/src/main/java/com/hg4/oopalgorithm/oopalgorithm/AlgorithmRunner.java
                    sensor!.patchInfo = Data([0xDF, 0x00, 0x00, 0x01, 0x01, 0x02])
                }
                sensor!.fram = Data(buffer[18 ..< 362])
                main.info("\n\n\(sensor!.type)  +  \(name)")
            }
        }
    }
}
