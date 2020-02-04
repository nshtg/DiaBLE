import Foundation


enum WatchType: String, CaseIterable, Hashable, Codable, Identifiable {
    case none, appleWatch, watlaa
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none:       return "Any"
        case .appleWatch: return AppleWatch.name
        case .watlaa:     return Watlaa.name
        }
    }
    var type: AnyClass {
        switch self {
        case .none:       return Watch.self
        case .appleWatch: return AppleWatch.self
        case .watlaa:     return Watlaa.self
        }
    }
}


class Watch: Transmitter {
    override class var type: DeviceType { DeviceType.watch(.none) }
}


class AppleWatch: Watch {
    override class var type: DeviceType { DeviceType.watch(.appleWatch) }
    override class var name: String { "Apple Watch" }
}

class Watlaa: Watch {
    override class var type: DeviceType { DeviceType.watch(.watlaa) }
    override class var name: String { "Watlaa" }
    override class var dataServiceUUID: String { "00001010-1212-EFDE-0137-875F45AC0113" }
    override class var dataReadCharacteristicUUID: String { "00001011-1212-EFDE-0137-875F45AC0113" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case dataRead     = "00001011-1212-EFDE-0137-875F45AC0113"
        case bridgeStatus = "00001012-1212-EFDE-0137-875F45AC0113"
        case lastGlucose  = "00001013-1212-EFDE-0137-875F45AC0113"
        case calibration  = "00001014-1212-EFDE-0137-875F45AC0113"
        case glucoseUnit  = "00001015-1212-EFDE-0137-875F45AC0113"
        case alerts       = "00001016-1212-EFDE-0137-875F45AC0113"
        case unknown      = "00001017-1212-EFDE-0137-875F45AC0113"

        var description: String {
            switch self {
            case .dataRead:     return "raw glucose data"
            case .bridgeStatus: return "bridge connection status"
            case .lastGlucose:  return "last glucose raw value"
            case .calibration:  return "calibration"
            case .glucoseUnit:  return "glucose unit"
            case .alerts:       return "alerts settings"
            case .unknown:      return "unknown"
            }
        }
    }

    var slope: Float = 0.0
    var intercept: Float = 0.0
    var lastGlucose: Int = 0
    var lastGlucoseAge: Int = 0
    var unit: GlucoseUnit = .mgdl

    var lastReadingDate: Date = Date()

    func readValue(for uuid: UUID) {
        peripheral?.readValue(for: characteristics[uuid.rawValue]!)
        main.debugLog("\(name): requested value for \(uuid)")
    }


    override func read(_ data: Data, for uuid: String) {

        let description = UUID(rawValue: uuid)?.description ?? uuid
        main.log("\(name): received value for \(description) characteristic")

        switch UUID(rawValue: uuid) {

        case .dataRead:
            if sensor == nil {
                if main.app.sensor != nil {
                    sensor = main.app.sensor
                } else {
                    sensor = Sensor(transmitter: self)
                    main.app.sensor = sensor
                }
            }
            if buffer.count == 0 { sensor!.lastReadingDate = main.app.lastReadingDate }
            lastReadingDate = main.app.lastReadingDate
            buffer.append(data)
            main.log("\(name): partial buffer count: \(buffer.count)")

            if buffer.count == 344 {
                let fram = buffer[..<344]
                sensor!.fram = Data(fram)
                readSetup()
                main.info("\n\n\(sensor!.type)  +  \(name)")
            }

        case .lastGlucose:
            let value = Int(data[1]) << 8 + Int(data[0])
            let age   = Int(data[3]) << 8 + Int(data[2])
            lastGlucose = value
            lastGlucoseAge = age
            main.log("\(name): last raw glucose: \(value), age: \(age) minutes")

        case .calibration:
            let slope:     Float = Data(data[0...3]).withUnsafeBytes { $0.load(as: Float.self) }
            let intercept: Float = Data(data[4...7]).withUnsafeBytes { $0.load(as: Float.self) }
            self.slope = slope
            self.intercept = intercept
            main.log("\(name): slope: \(slope), intercept: \(intercept)")

        case .glucoseUnit:
            if let unit = GlucoseUnit(rawValue: GlucoseUnit.allCases[Int(data[0])].rawValue) {
                main.log("\(name): glucose unit: \(unit)")
                self.unit = unit
            }

        case .bridgeStatus:
            let status = Int(data[0])
            var description = "N/A"
            switch status {
            case 0: description = "no connection"
            case 1: description = "bridge connected, sensor inactive"
            case 2: description = "bridge connected, sensor active"
            default: break
            }
            main.log("\(name): transmitter connection status: \(description)")

        case .alerts:
            let high: Float = Data(data[0...3]).withUnsafeBytes { $0.load(as: Float.self) }
            let low:  Float = Data(data[4...7]).withUnsafeBytes { $0.load(as: Float.self) }
            let bridgeConnection: Int = Int(data[9]) << 8 + Int(data[8])
            let lowSnooze: Int  = Int(data[11]) << 8 + Int(data[10])
            let highSnooze: Int = Int(data[13]) << 8 + Int(data[12])
            let signals: UInt8 = data[14]
            let sensorLostVibration: Bool = (signals >> 3) & 1 == 1
            let glucoseVibration: Bool    = (signals >> 1) & 1 == 1

            main.log("\(name): alerts: high: \(high), low: \(low), bridge connection: \(bridgeConnection) minutes, low snooze: \(lowSnooze) minutes, high snooze: \(highSnooze) minutes, sensor lost vibration: \(sensorLostVibration), glucose vibration: \(glucoseVibration)")

        default:
            break
        }
    }


    func readSetup() {
        readValue(for: .calibration)
        readValue(for: .glucoseUnit)
        readValue(for: .lastGlucose)
        readValue(for: .bridgeStatus)
        readValue(for: .alerts)
    }
}
