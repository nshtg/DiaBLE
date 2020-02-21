import Foundation

class App: ObservableObject {

    @Published var device: Device!
    @Published var transmitter: Transmitter!
    @Published var sensor: Sensor!
    @Published var watch: Watch!

    var main: MainDelegate!

    @Published var selectedTab: Tab = .monitor

    @Published var currentGlucose: Int
    @Published var lastReadingDate: Date
    @Published var oopAlarm: String
    @Published var oopTrend: String

    @Published var deviceState: String
    @Published var info: String

    @Published var calibration: Calibration {
        didSet(value) {
            if editingCalibration {
                main.applyCalibration(sensor: sensor)
            }
        }
    }
    @Published var editingCalibration: Bool

    @Published var showingJavaScriptConfirmAlert = false
    @Published var JavaScriptConfirmAlertMessage = ""
    @Published var JavaScriptAlertReturn = ""

    init(
        device: Device! = nil,
        transmitter: Transmitter! = nil,
        sensor: Sensor! = nil,
        watch: Watch! = nil,

        selectedTab: Tab = .monitor,

        currentGlucose: Int = 0,
        lastReadingDate: Date = Date(),
        oopAlarm: String = "",
        oopTrend: String = "",

        deviceState: String = "",
        info: String = "Welcome to DiaBLE!",

        calibration: Calibration = Calibration(),
        editingCalibration: Bool = true) {


        self.device = device
        self.transmitter = transmitter
        self.sensor = sensor
        self.watch = watch
        
        self.selectedTab = selectedTab

        self.currentGlucose = currentGlucose
        self.lastReadingDate = lastReadingDate
        self.oopAlarm = oopAlarm
        self.oopTrend = oopTrend

        self.deviceState = deviceState
        self.info = info

        self.calibration = calibration
        self.editingCalibration = editingCalibration
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
        "disabledNotifications": false,

        "calendarTitle": "",
        "calendarAlarmIsOn": false,

        "logging": false,
        "reversedLog": true,
        "debugLevel": 0,

        "nightscoutSite": "dashboard.heroku.com/apps",
        "nightscoutToken": "",

        "patchUid": Data(),
        "patchInfo": Data(),

        "oopCalibration": try! JSONEncoder().encode(Calibration())
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

    @Published var disabledNotifications: Bool = UserDefaults.standard.bool(forKey: "disabledNotifications") {
        didSet { UserDefaults.standard.set(self.disabledNotifications, forKey: "disabledNotifications") }
    }

    @Published var calendarTitle: String = UserDefaults.standard.string(forKey: "calendarTitle")! {
        didSet { UserDefaults.standard.set(self.calendarTitle, forKey: "calendarTitle") }
    }

    @Published var calendarAlarmIsOn: Bool = UserDefaults.standard.bool(forKey: "calendarAlarmIsOn") {
        didSet { UserDefaults.standard.set(self.calendarAlarmIsOn, forKey: "calendarAlarmIsOn") }
    }

    @Published var logging: Bool = UserDefaults.standard.bool(forKey: "logging") {
        didSet { UserDefaults.standard.set(self.logging, forKey: "logging") }
    }

    @Published var reversedLog: Bool = UserDefaults.standard.bool(forKey: "reversedLog") {
        didSet { UserDefaults.standard.set(self.reversedLog, forKey: "reversedLog") }
    }

    @Published var debugLevel: Int = UserDefaults.standard.integer(forKey: "debugLevel") {
        didSet { UserDefaults.standard.set(self.debugLevel, forKey: "debugLevel") }
    }

    @Published var nightscoutSite: String = UserDefaults.standard.string(forKey: "nightscoutSite")! {
        didSet { UserDefaults.standard.set(self.nightscoutSite, forKey: "nightscoutSite") }
    }

    @Published var nightscoutToken: String = UserDefaults.standard.string(forKey: "nightscoutToken")! {
        didSet { UserDefaults.standard.set(self.nightscoutToken, forKey: "nightscoutToken") }
    }

    @Published var patchUid: Data = UserDefaults.standard.data(forKey: "patchUid")! {
        didSet { UserDefaults.standard.set(self.patchUid, forKey: "patchUid") }
    }

    @Published var patchInfo: Data = UserDefaults.standard.data(forKey: "patchInfo")! {
        didSet { UserDefaults.standard.set(self.patchInfo, forKey: "patchInfo") }
    }

    @Published var oopCalibration: Calibration = try! JSONDecoder().decode(Calibration.self, from: UserDefaults.standard.data(forKey: "oopCalibration")!) {
        didSet { UserDefaults.standard.set(try! JSONEncoder().encode(self.oopCalibration), forKey: "oopCalibration") }
    }


    @Published var numberFormatter: NumberFormatter

    @Published var oopServer: OOPServer



    init(
        preferredTransmitter: TransmitterType = TransmitterType(rawValue: UserDefaults.standard.string(forKey: "preferredTransmitter")!)!,
        preferredWatch: WatchType = WatchType(rawValue: UserDefaults.standard.string(forKey: "preferredWatch")!)!,
        preferredDevicePattern: String = UserDefaults.standard.string(forKey: "preferredDevicePattern")!,

        readingInterval: Int = UserDefaults.standard.integer(forKey: "readingInterval"),
        glucoseUnit: GlucoseUnit = GlucoseUnit(rawValue: UserDefaults.standard.string(forKey: "glucoseUnit")!)!,

        patchUid: Data = UserDefaults.standard.data(forKey: "patchUid")!,
        patchInfo: Data = UserDefaults.standard.data(forKey: "patchInfo")!,

        targetLow:  Double = UserDefaults.standard.double(forKey: "targetLow"),
        targetHigh: Double = UserDefaults.standard.double(forKey: "targetHigh"),
        alarmLow:   Double = UserDefaults.standard.double(forKey: "alarmLow"),
        alarmHigh:  Double = UserDefaults.standard.double(forKey: "alarmHigh"),
        mutedAudio: Bool = UserDefaults.standard.bool(forKey: "mutedAudio"),
        disabledNotifications: Bool = UserDefaults.standard.bool(forKey: "disabledNotifications"),

        calendarTitle: String = UserDefaults.standard.string(forKey: "calendarTitle")!,
        calendarAlarmIsOn: Bool = UserDefaults.standard.bool(forKey: "calendarAlarmIsOn"),

        logging: Bool = UserDefaults.standard.bool(forKey: "logging"),
        reversedLog: Bool = UserDefaults.standard.bool(forKey: "reversedLog"),
        debugLevel: Int = UserDefaults.standard.integer(forKey: "debugLevel"),

        numberFormatter: NumberFormatter = NumberFormatter(),

        nightscoutSite: String = UserDefaults.standard.string(forKey: "nightscoutSite")!,
        nightscoutToken: String = UserDefaults.standard.string(forKey: "nightscoutToken")!,

        oopServer: OOPServer = OOPServer.default,
        oopCalibration: Calibration = try! JSONDecoder().decode(Calibration.self, from: UserDefaults.standard.data(forKey: "oopCalibration")!)

    ) {
        self.preferredTransmitter = preferredTransmitter
        self.preferredWatch = preferredWatch
        self.preferredDevicePattern = preferredDevicePattern
        self.readingInterval = readingInterval
        self.glucoseUnit = glucoseUnit

        self.patchUid = patchUid
        self.patchInfo = patchInfo

        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.alarmLow = alarmLow
        self.alarmHigh = alarmHigh
        self.mutedAudio = mutedAudio
        self.disabledNotifications = disabledNotifications

        self.calendarTitle = calendarTitle
        self.calendarAlarmIsOn = calendarAlarmIsOn

        self.logging = logging
        self.reversedLog = reversedLog
        self.debugLevel = debugLevel

        self.numberFormatter = numberFormatter
        numberFormatter.minimumFractionDigits = 6

        self.nightscoutSite = nightscoutSite
        self.nightscoutToken = nightscoutToken
        self.oopServer = oopServer
        self.oopCalibration = oopCalibration
    }
}


// For UI testing

extension App {
    static func test(tab: Tab) -> App {
        return App(
            device: Watlaa(),
            transmitter: Transmitter(battery: 54, firmware: "4.56", manufacturer: "Acme Inc.", hardware: "2.3", macAddress: Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])),
            sensor: Sensor(state: .ready, serial: "0M0008B8CSR", age: 3407),
            selectedTab: tab,
            currentGlucose: 234,
            oopAlarm: "HIGH_GLUCOSE",
            oopTrend: "FALLING",
            deviceState: "Connected",
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
