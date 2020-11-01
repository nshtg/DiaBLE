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
            if buffer.count == 20 + 18 + 8 {
                let bleGlucose = parseBLEData(Data(try! Libre2.decryptBLE(id: sensor!.uid, data: buffer)))
                let trend = bleGlucose.map { factoryGlucose(raw: $0, calibrationInfo: main.settings.activeSensorCalibrationInfo) }
                main.log("BLE trend: \(trend.map{$0.value})")
                main.log("BLE temperatures: \(trend.map{Double(String(format: "%.1f", $0.temperature))!})")
                sensor!.currentGlucose = trend[0].value
                main.history.factoryTrend = trend
                main.history.rawTrend = bleGlucose
                // TODO: insert into history every 5 minutes (only the 10th value?)
                main.log("DEBUG: settings.mutedAudio \(main.settings.mutedAudio)") // FIXME
                main.status("\(sensor!.type)  +  BLE")
                buffer = Data()
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
        for i in 0 ..< 10 {
            let raw = readBits(data, i * 4, 0, 0xe)
            let rawTemperature = readBits(data, i * 4, 0xe, 0xc) << 2
            var temperatureAdjustment = readBits(data, i * 4, 0x1a, 0x5) << 2
            let negativeAdjustment = readBits(data, i * 4, 0x1f, 0x1)
            if negativeAdjustment != 0 {
                temperatureAdjustment = -temperatureAdjustment
            }
            let id = Int(wearTimeMinutes) - i
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
