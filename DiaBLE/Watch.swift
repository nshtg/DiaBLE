import Foundation
import EventKit


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

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data           = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataWrite      = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataRead       = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
        case legacyData     = "00001010-1212-EFDE-0137-875F45AC0113"
        case legacyDataRead = "00001011-1212-EFDE-0137-875F45AC0113"
        case bridgeStatus   = "00001012-1212-EFDE-0137-875F45AC0113"
        case lastGlucose    = "00001013-1212-EFDE-0137-875F45AC0113"
        case calibration    = "00001014-1212-EFDE-0137-875F45AC0113"
        case glucoseUnit    = "00001015-1212-EFDE-0137-875F45AC0113"
        case alerts         = "00001016-1212-EFDE-0137-875F45AC0113"
        case unknown        = "00001017-1212-EFDE-0137-875F45AC0113"
        case unknown2       = "00001018-1212-EFDE-0137-875F45AC0113"

        var description: String {
            switch self {
            case .data:           return "data"
            case .dataRead:       return "data read"
            case .dataWrite:      return "data write"
            case .legacyData:     return "data (legacy)"
            case .legacyDataRead: return "raw glucose data (legacy)"
            case .bridgeStatus:   return "bridge connection status"
            case .lastGlucose:    return "last glucose raw value"
            case .calibration:    return "calibration"
            case .glucoseUnit:    return "glucose unit"
            case .alerts:         return "alerts settings"
            case .unknown,
                 .unknown2:       return "unknown"
            }
        }
    }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }
    class var legacyDataServiceUUID: String                { UUID.legacyData.rawValue }
    class var legacyDataReadCharacteristicUUID: String     { UUID.legacyDataRead.rawValue }

    // Same as MiaoMiao
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


    // Same as MiaoMiao
    override func readCommand(interval: Int = 5) -> [UInt8] {
        var command = [UInt8(0xF0)]
        if [1, 3].contains(interval) {
            command.insert(contentsOf: [0xD1, UInt8(interval)], at: 0)
        }
        return command
    }


    override func read(_ data: Data, for uuid: String) {

        let description = UUID(rawValue: uuid)?.description ?? uuid
        main.log("\(name): received value for \(description) characteristic")

        switch UUID(rawValue: uuid) {


        // MiaoMiao protocol
        case .dataRead:

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
                        sensor!.patchInfo = Data([0xDF, 0x00, 0x00, 0x01, 0x01, 0x02])
                    }
                    sensor!.fram = Data(buffer[18 ..< 362])
                    main.info("\n\n\(sensor!.type)  +  \(name)")
                }
            }


        case .legacyDataRead:
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


// https://github.com/JohanDegraeve/xdripswift/blob/master/xdrip/Managers/Watch/WatchManager.swift

// TODO:

class EventKit {

    /// Main app delegate
    var main: MainDelegate
    var store: EKEventStore = EKEventStore()
    var calendarTitles = [String]()

    init(main: MainDelegate) {
        self.main = main
    }


    func sync(handler: ((EKCalendar?) -> ())? = nil) {

        store.requestAccess(to: .event) { granted, error  in
            guard granted
                else {
                    self.main.debugLog("EventKit: access not granted")
                    return
            }

            guard EKEventStore.authorizationStatus(for: .event) == .authorized
                else {
                    self.main.log("EventKit: access to calendar events not authorized")
                    return
            }

            self.calendarTitles = self.store.calendars(for: .event)
                .filter { $0.allowsContentModifications }
                .map { $0.title }

            guard self.main.settings.calendarTitle != "" else { return }

            var calendar: EKCalendar?
            for storeCalendar in self.store.calendars(for: .event) {
                if storeCalendar.title == self.main.settings.calendarTitle {
                    calendar = storeCalendar
                    break
                }
            }

            if calendar == nil {
                calendar = self.store.defaultCalendarForNewEvents
            }

            let predicate = self.store.predicateForEvents(withStart: Calendar.current.date(byAdding: .year, value: -4, to : Date())!, end: Date(), calendars: [calendar!])
            for event in self.store.events(matching: predicate) {
                if let notes = event.notes {
                    if notes.contains("Created by DiaBLE") {
                        do {
                            try self.store.remove(event, span: .thisEvent)
                        } catch {
                            self.main.debugLog("EventKit: error while deleting calendar events created by DiaBLE: \(error.localizedDescription)")
                        }
                    }
                }
            }

            var currentGlucose = self.main.app.currentGlucose
            var title = currentGlucose > 0 ?
                "\(currentGlucose)" :
                (currentGlucose < 0 ?
                    "(\(-currentGlucose))" : "---")

            currentGlucose = abs(currentGlucose)
            if currentGlucose != 0 {
                title += "  \(self.main.settings.glucoseUnit)"
                title += "  \(OOP.alarmDescription(for: self.main.app.oopAlarm))  \(OOP.trendSymbol(for: self.main.app.oopTrend))"

                // TODO: delta

                let event = EKEvent(eventStore: self.store)
                event.title = title
                event.notes = "Created by DiaBLE"
                event.startDate = Date()
                event.endDate = Date(timeIntervalSinceNow: TimeInterval(60 * self.main.settings.readingInterval))
                event.calendar = calendar

                if self.main.settings.calendarAlarmIsOn {
                    if currentGlucose > 0 && (currentGlucose > Int(self.main.settings.alarmHigh) || currentGlucose < Int(self.main.settings.alarmLow)) {
                        let alarm = EKAlarm(relativeOffset: 1)
                        event.addAlarm(alarm)
                    }
                }

                do {
                    try self.store.save(event, span: .thisEvent)
                } catch {
                    self.main.log("EventKit: error while saving event: \(error.localizedDescription)")
                }
                handler?(calendar)
            }
        }
    }
}
