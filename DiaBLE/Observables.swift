import Foundation

class App: ObservableObject {

    @Published var transmitter: Transmitter!
    @Published var sensor: Sensor!
    @Published var watch: Transmitter!

    var main: MainDelegate!

    @Published var selectedTab: Tab = .monitor

    @Published var currentGlucose: Int
    @Published var lastReadingDate: Date
    @Published var oopAlarm: String
    @Published var oopTrend: String

    @Published var transmitterState: String
    @Published var info: String

    @Published var calibration: Calibration

    @Published var showingJavaScriptConfirmAlert = false
    @Published var JavaScriptConfirmAlertMessage = ""
    @Published var JavaScriptAlertReturn = ""

    init(
        transmitter: Transmitter! = nil,
        sensor: Sensor! = nil,
        watch: Transmitter! = nil,

        selectedTab: Tab = .monitor,

        currentGlucose: Int = 0,
        lastReadingDate: Date = Date(),
        oopAlarm: String = "",
        oopTrend: String = "",

        transmitterState: String = "",
        info: String = "Welcome to DiaBLE!",


        calibration: Calibration = Calibration()) {

        self.transmitter = transmitter
        self.sensor = sensor
        
        self.selectedTab = selectedTab

        self.currentGlucose = currentGlucose
        self.lastReadingDate = lastReadingDate
        self.oopAlarm = oopAlarm
        self.oopTrend = oopTrend

        self.transmitterState = transmitterState
        self.info = info

        self.calibration = calibration
    }
}


class Log: ObservableObject {
    @Published var text: String
    init(_ text: String = "Log \(Date().local)\n") {
        self.text = text
    }
}


class History: ObservableObject {
    @Published var values:    [Glucose]
    @Published var rawValues: [Glucose]
    @Published var rawTrend:  [Glucose]
    @Published var calibratedValues: [Glucose]
    @Published var calibratedTrend:  [Glucose]
    @Published var storedValues: [Glucose]
    @Published var nightscoutValues: [Glucose]


    init(values:    [Glucose] = [],
         rawValues: [Glucose] = [],
         rawTrend:  [Glucose] = [],
         calibratedValues: [Glucose] = [],
         calibratedTrend:  [Glucose] = [],
         storedValues: [Glucose] = [],
         nightscoutValues: [Glucose] = []
    ) {
        self.values    = values
        self.rawValues = rawValues
        self.rawTrend  = rawTrend
        self.calibratedValues = calibratedValues
        self.calibratedTrend  = calibratedTrend
        self.storedValues  = storedValues
        self.nightscoutValues  = nightscoutValues
    }
}


class Settings: ObservableObject {

    static let defaults: [String: Any] = [
        "preferredTransmitter": TransmitterType.none.id,
        "preferredWatch": WatchType.none.id,
        "preferredDevicePattern": BLE.knownDevicesIds.joined(separator: " "),
        "readingInterval": 5,
        "glucoseUnit": GlucoseUnit.mgdl.rawValue,

        "targetLow": 80.0,
        "targetHigh": 170.0,
        "alarmLow": 70.0,
        "alarmHigh": 200.0,
        "mutedAudio": false,

        "createCalendarEvents": false,
        "calendarTitle": "",

        "logging": true,
        "reversedLog": true,
        "debugLevel": 0,

        "nightscoutSite": "dashboard.heroku.com/apps",
        "nightscoutToken": ""
    ]


    @Published var preferredTransmitter: TransmitterType = TransmitterType(rawValue: UserDefaults.standard.string(forKey: "preferredTransmitter")!)! {
        willSet(type) {
            if type == .miaomiao && readingInterval > 5 {
                readingInterval = 5
            }
            if type != .none && preferredWatch != .none {
                preferredWatch = .none
            }
            if type != .none {
                preferredDevicePattern = type.id
            } else {
                preferredDevicePattern = ""
            }
        }
        didSet { UserDefaults.standard.set(self.preferredTransmitter.id, forKey: "preferredTransmitter") }
    }

    @Published var preferredWatch: WatchType = WatchType(rawValue: UserDefaults.standard.string(forKey: "preferredWatch")!)! {
        willSet(type) {
            if type != .none && preferredTransmitter != .none {
                preferredTransmitter = .none
            }
            if type != .none && preferredDevicePattern != "" {
                preferredDevicePattern = ""
            }
        }
        didSet { UserDefaults.standard.set(self.preferredWatch.rawValue, forKey: "preferredWatch") }
    }

    @Published var preferredDevicePattern: String = UserDefaults.standard.string(forKey: "preferredDevicePattern")! {
        willSet(pattern) {
            if !pattern.isEmpty {
                if !preferredTransmitter.id.matches(pattern) {
                    preferredTransmitter = .none
                }
                if !preferredWatch.id.matches(pattern) {
                    preferredWatch = .none
                }
            }
        }
        didSet { UserDefaults.standard.set(self.preferredDevicePattern, forKey: "preferredDevicePattern") }
    }
    
    @Published var readingInterval: Int = UserDefaults.standard.integer(forKey: "readingInterval")  {
        didSet { UserDefaults.standard.set(self.readingInterval, forKey: "readingInterval") }
    }

    @Published var glucoseUnit: GlucoseUnit = GlucoseUnit(rawValue: UserDefaults.standard.string(forKey: "glucoseUnit")!)!  {
        didSet { UserDefaults.standard.set(self.glucoseUnit.rawValue, forKey: "glucoseUnit") }
    }

    @Published var targetLow: Double = UserDefaults.standard.double(forKey: "targetLow") {
        didSet { UserDefaults.standard.set(self.targetLow, forKey: "targetLow") }
    }
    @Published var targetHigh: Double = UserDefaults.standard.double(forKey: "targetHigh") {
        didSet { UserDefaults.standard.set(self.targetHigh, forKey: "targetHigh") }
    }
    @Published var alarmLow: Double = UserDefaults.standard.double(forKey: "alarmLow") {
        didSet { UserDefaults.standard.set(self.alarmLow, forKey: "alarmLow") }
    }
    @Published var alarmHigh: Double = UserDefaults.standard.double(forKey: "alarmHigh") {
        didSet { UserDefaults.standard.set(self.alarmHigh, forKey: "alarmHigh") }
    }

    @Published var mutedAudio: Bool = UserDefaults.standard.bool(forKey: "mutedAudio") {
        didSet { UserDefaults.standard.set(self.mutedAudio, forKey: "mutedAudio") }
    }

    @Published var createCalendarEvents: Bool = UserDefaults.standard.bool(forKey: "createCalendarEvents") {
        didSet { UserDefaults.standard.set(self.createCalendarEvents, forKey: "createCalendarEvents") }
    }

    @Published var calendarTitle: String = UserDefaults.standard.string(forKey: "calendarTitle")! {
        didSet { UserDefaults.standard.set(self.calendarTitle, forKey: "calendarTitle") }
    }

    @Published var logging: Bool = UserDefaults.standard.bool(forKey: "logging") {
        didSet { UserDefaults.standard.set(self.logging, forKey: "logging") }
    }

    @Published var reversedLog: Bool =  UserDefaults.standard.bool(forKey: "reversedLog") {
        didSet { UserDefaults.standard.set(self.reversedLog, forKey: "reversedLog") }
    }

    @Published var debugLevel: Int =  UserDefaults.standard.integer(forKey: "debugLevel") {
        didSet { UserDefaults.standard.set(self.debugLevel, forKey: "debugLevel") }
    }

    @Published var nightscoutSite: String =  UserDefaults.standard.string(forKey: "nightscoutSite")! {
        didSet { UserDefaults.standard.set(self.nightscoutSite, forKey: "nightscoutSite") }
    }

    @Published var nightscoutToken: String =  UserDefaults.standard.string(forKey: "nightscoutToken")! {
        didSet { UserDefaults.standard.set(self.nightscoutToken, forKey: "nightscoutToken") }
    }


    @Published var numberFormatter: NumberFormatter

    @Published var oopServer: OOPServer



    init(
        preferredTransmitter: TransmitterType = TransmitterType(rawValue: UserDefaults.standard.string(forKey: "preferredTransmitter")!)!,
        preferredWatch: WatchType = WatchType(rawValue: UserDefaults.standard.string(forKey: "preferredWatch")!)!,
        preferredDevicePattern: String = UserDefaults.standard.string(forKey: "preferredDevicePattern")!,

        readingInterval: Int = UserDefaults.standard.integer(forKey: "readingInterval"),
        glucoseUnit: GlucoseUnit = GlucoseUnit(rawValue: UserDefaults.standard.string(forKey: "glucoseUnit")!)!,

        targetLow:  Double = UserDefaults.standard.double(forKey: "targetLow"),
        targetHigh: Double = UserDefaults.standard.double(forKey: "targetHigh"),
        alarmLow:   Double = UserDefaults.standard.double(forKey: "alarmLow"),
        alarmHigh:  Double = UserDefaults.standard.double(forKey: "alarmHigh"),
        mutedAudio: Bool = UserDefaults.standard.bool(forKey: "mutedAudio"),

        createCalendarEvents: Bool = UserDefaults.standard.bool(forKey: "createCalendarEvents"),
        calendarTitle: String = UserDefaults.standard.string(forKey: "calendarTitle")!,

        logging: Bool = UserDefaults.standard.bool(forKey: "logging"),
        reversedLog: Bool = UserDefaults.standard.bool(forKey: "reversedLog"),
        debugLevel: Int = UserDefaults.standard.integer(forKey: "debugLevel"),

        numberFormatter: NumberFormatter = NumberFormatter(),

        nightscoutSite: String = UserDefaults.standard.string(forKey: "nightscoutSite")!,
        nightscoutToken: String = UserDefaults.standard.string(forKey: "nightscoutToken")!,

        oopServer: OOPServer = OOPServer.default
    ) {
        self.preferredTransmitter = preferredTransmitter
        self.preferredWatch = preferredWatch
        self.preferredDevicePattern = preferredDevicePattern
        self.readingInterval = readingInterval
        self.glucoseUnit = glucoseUnit 

        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.alarmLow = alarmLow
        self.alarmHigh = alarmHigh
        self.mutedAudio = mutedAudio

        self.createCalendarEvents = createCalendarEvents
        self.calendarTitle = calendarTitle

        self.logging = logging
        self.reversedLog = reversedLog
        self.debugLevel = debugLevel

        self.numberFormatter = numberFormatter
        numberFormatter.minimumFractionDigits = 6

        self.nightscoutSite = nightscoutSite
        self.nightscoutToken = nightscoutToken
        self.oopServer = oopServer
    }
}


// For UI testing

extension App {
    static func test(tab: Tab) -> App {
        return App(
            transmitter: Transmitter(battery: 54, firmware: "4.56", hardware: "Version 1.23\nManufacturer", macAddress: Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])),
            sensor: Sensor(state: .ready, serial: "0M0008B8CSR", age: 3407),
            selectedTab: tab,
            currentGlucose: 234,
            oopAlarm: "HIGH_GLUCOSE",
            oopTrend: "FALLING",
            transmitterState: "Connected",
            info: "Sensor + Transmitter\nError about connection\nError about sensor",
            calibration: Calibration(slopeSlope: 0.123456, slopeOffset: 0.123456, offsetOffset: -15.123456, offsetSlope: 0.123456)
        )
    }
}


extension History {
    static var test: History {
        return History(
            values: [231, 252, 253, 254, 245, 196, 177, 128, 149, 150, 101, 122, 133, 144, 155, 166, 177, 178, 149, 140, 141, 142, 143, 144, 155, 166, 177, 178, 169, 150, 141, 132].enumerated().map { Glucose($0.1, id: 5000 - $0.1 * 15, date: Date() - Double($0.1) * 15 * 60) } ,
            rawValues: [241, 252, 263, 254, 205, 196, 187, 138, 159, 160, 121, 132, 133, 154, 165, 176, 157, 148, 149, 140, 131, 132, 143, 154, 155, 176, 177, 168, 159, 150, 142].enumerated().map { Glucose($0.1, id: 5000 - $0.0 * 15, date: Date() - Double($0.1) * 15 * 60) },
            rawTrend: [241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 241, 242, 243, 244, 245].enumerated().map { Glucose($0.1, id: 5000 - $0.0, date: Date() - Double($0.1) * 60) },
            calibratedValues: [231, 242, 243, 244, 255, 216, 197, 138, 159, 120, 101, 102, 143, 154, 165, 186, 187, 168, 139, 130, 131, 142, 143, 144, 155, 166, 177, 188, 169, 150, 141, 132].enumerated().map { Glucose($0.1, id: 5000 - $0.0 * 15, date: Date() - Double($0.1) * 15 * 60) },
            calibratedTrend: [231, 232, 233, 234, 235, 236, 237, 238, 239, 230, 231, 232, 233, 234, 235].enumerated().map { Glucose($0.1, id: 5000 - $0.0, date: Date() - Double($0.1) * 60) },
            storedValues: [231, 252, 253, 254, 245, 196, 177, 128, 149, 150, 101, 122, 133, 144, 155, 166, 177, 178, 149, 140, 141, 142, 143, 144, 155, 166, 177, 178, 169, 150, 141, 132].enumerated().map { Glucose($0.1, id: $0.0, date: Date() - Double($0.1) * 15 * 60, source: "SourceApp com.example.sourceapp") },
            nightscoutValues: [231, 252, 253, 254, 245, 196, 177, 128, 149, 150, 101, 122, 133, 144, 155, 166, 177, 178, 149, 140, 141, 142, 143, 144, 155, 166, 177, 178, 169, 150, 141, 132].enumerated().map { Glucose($0.1, id: $0.0, date: Date() - Double($0.1) * 15 * 60, source: "Device") }
        )
    }
}
