import Foundation


// https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/UtilityModels/Blukon.java
// https://github.com/dabear/LinkBluCon/blob/master/LinkBluCon/LinkBluCon/BluConDeviceManager.swift
// https://github.com/JohanDegraeve/xdripswift/tree/master/xdrip/BluetoothTransmitter/CGM/Libre/Blucon

class BluCon: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.blu) }
    override class var name: String { "BluCon" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data      = "436A62C0-082E-4CE8-A08B-01D81F195B24"
        case dataWrite = "436AA6E9-082E-4CE8-A08B-01D81F195B24"
        case dataRead  = "436A0C82-082E-4CE8-A08B-01D81F195B24"

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

    enum ResponseType: String, CustomStringConvertible {
        case unknown = "000000"
        // TODO

        var description: String {
            switch self {
            default:  return "unknown"
            }
        }
    }


    override func readCommand(interval: Int = 5) -> [UInt8] {
        return [0x00] // TODO
    }


    override func parseManufacturerData(_ data: Data) {
        // TODO
    }


    override func read(_ data: Data, for uuid: String) {
        if data.count > 0 {
            let response = ResponseType(rawValue: data.string)
            main.log("\(name) response: \(response?.description ?? "unknown") (0x\(data.hex))")
        }

        // TODO

    }
}
