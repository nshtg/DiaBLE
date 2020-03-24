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
