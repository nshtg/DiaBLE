import Foundation


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

        "calibration": try! JSONEncoder().encode(Calibration()),
        "oopCalibration": try! JSONEncoder().encode(Calibration())
    ]


    @Published var preferredTransmitter: TransmitterType = TransmitterType(rawValue: UserDefaults.standard.string(forKey: "preferredTransmitter")!) ?? .none {
        willSet(type) {
            if type == .blu || (type == .miaomiao && readingInterval > 5) {
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

    @Published var numberFormatter: NumberFormatter = NumberFormatter()

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

    @Published var calibration: Calibration = try! JSONDecoder().decode(Calibration.self, from: UserDefaults.standard.data(forKey: "calibration")!) {
        didSet { UserDefaults.standard.set(try! JSONEncoder().encode(self.calibration), forKey: "calibration") }
    }

    @Published var oopServer: OOPServer = OOPServer.default

    @Published var oopCalibration: Calibration = try! JSONDecoder().decode(Calibration.self, from: UserDefaults.standard.data(forKey: "oopCalibration")!) {
        didSet { UserDefaults.standard.set(try! JSONEncoder().encode(self.oopCalibration), forKey: "oopCalibration") }
    }

}
