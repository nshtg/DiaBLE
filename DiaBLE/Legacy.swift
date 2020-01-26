import Foundation


class Droplet: Transmitter {
    // override class var type: DeviceType { DeviceType.transmitter(.droplet) }
    override class var name: String { "Droplet" }
    override class var dataServiceUUID: String { "C97433F0-BE8F-4DC8-B6F0-5343E6100EB4" }
    override class var dataReadCharacteristicUUID: String { "C97433F1-BE8F-4DC8-B6F0-5343E6100EB4" }
    override class var dataWriteCharacteristicUUID: String { "C97433F2-BE8F-4DC8-B6F0-5343E6100EB4" }

    enum LibreType: String, CustomStringConvertible {
        case L1   = "10"
        case L2   = "20"
        case US14 = "30"
        case Lpro = "40"

        var description: String {
            switch self {
            case .L1:   return "Libre 1"
            case .L2:   return "Libre 2"
            case .US14: return "Libre US 14d"
            case .Lpro: return "Libre Pro"
            }
        }
    }

    override func read(_ data: Data, for uuid: String) {
        if sensor == nil {
            sensor = Sensor(transmitter: self)
            main.app.sensor = sensor
        }
        if data.count == 8 {
            sensor!.uid = Data(data)
            main.log("\(name): sensor serial number: \(sensor!.serial))")
        } else {
            main.log("\(name) response: 0x\(data[0...0].hex)")
            main.log("\(name) response data length: \(Int(data[1]))")
        }
        // TODO:  9999 = error
    }
}


class Limitter: Droplet {
    // override class var type: DeviceType { DeviceType.transmitter(.limitter) }
    override class var name: String { "Limitter" }

    override func readCommand(interval: Int = 5) -> [UInt8] {
        return [UInt8(32 + interval)] // 0x2X
    }

    override func read(_ data: Data, for uuid: String) {

        // https://github.com/SpikeApp/Spike/blob/master/src/services/bluetooth/CGMBluetoothService.as

        if sensor == nil {
            sensor = Sensor(transmitter: self)
            main.app.sensor = sensor
        }

        let fields = data.string.split(separator: " ")
        guard fields.count == 4 else { return }

        battery = Int(fields[2])!
        main.log("\(name): battery: \(battery)")

        let firstField = fields[0]
        guard !firstField.hasPrefix("000") else {
            main.log("\(name): no sensor data")
            main.info("\n\n\(name): no data from sensor")
            if firstField.hasSuffix("999") {
                let err = fields[1]
                main.log("\(name): error \(err)\n(0001 = low battery, 0002 = badly positioned)")
            }
            return
        }

        let rawValue = Int(firstField.dropLast(2))!
        main.log("\(name): glucose raw value: \(rawValue)")
        main.info("\n\n\(name) raw glucose: \(rawValue)")
        sensor!.currentGlucose = rawValue / 10

        let sensorType = LibreType(rawValue: String(firstField.suffix(2)))!.description
        main.log("\(name): sensor type = \(sensorType)")

        sensor!.age = Int(fields[3])! * 10
        if Double(sensor!.age)/60/24 < 14.5 {
            sensor!.state = .ready
        } else {
            sensor!.state = .expired
        }
        main.log("\(name): sensor age: \(Int(sensor!.age)) minutes (\(String(format: "%.1f", Double(sensor!.age)/60/24)) days)")
        main.info("\n\n\(sensorType)  +  \(name)")
    }
}

// Legacy code from bluetoothDelegate didDiscoverCharacteristicsFor

// if app.transmitter.type == .transmitter(.droplet) && serviceUUID == Droplet.dataServiceUUID {

// https://github.com/MarekM60/eDroplet/blob/master/eDroplet/eDroplet/ViewModels/CgmPageViewModel.cs
// Droplet - New Protocol.pdf: https://www.facebook.com/download/preview/961042740919138

// app.transmitter.write([0x31, 0x32, 0x33]); log("Droplet: writing old ping command")
// app.transmitter.write([0x34, 0x35, 0x36]); log("Droplet: writing old read command")
// app.transmitter.write([0x50, 0x00, 0x00]); log("Droplet: writing ping command P00")
// app.transmitter.write([0x54, 0x00, 0x01]); log("Droplet: writing timer command T01")
// T05 = 5 minutes, T00 = quiet mode
// app.transmitter.write([0x53, 0x00, 0x00]); log("Droplet: writing sensor identification command S00")
// app.transmitter.write([0x43, 0x00, 0x01]); log("Droplet: writing FRAM reading command C01")
// app.transmitter.write([0x43, 0x00, 0x02]); log("Droplet: writing FRAM reading command C02")
// app.transmitter.write([0x42, 0x00, 0x01]); log("Droplet: writing RAM reading command B01")
// app.transmitter.write([0x42, 0x00, 0x02]); log("Droplet: writing RAM reading command B02")
// "A0xyz...z” sensor activation where: x=1 for Libre 1, 2 for Libre 2 and US 14-day, 3 for Libre Pro/H; y = length of activation bytes, z...z = activation bytes
// }

// if app.transmitter.type == .transmitter(.limitter) && serviceUUID == Limitter.dataServiceUUID {
//    let readCommand = app.transmitter.readCommand(interval: settings.readingInterval)
//    app.transmitter.write(readCommand)
//    log("Droplet (LimiTTer): writing start reading command 0x\(Data(readCommand).hex)")
//    app.transmitter.peripheral?.readValue(for: app.transmitter.readCharacteristic!)
//    log("Droplet (LimiTTer): reading data")
// }
