import SwiftUI
import CoreBluetooth
import AVFoundation


public class MainDelegate: NSObject, UNUserNotificationCenterDelegate {

    var app: App
    var log: Log
    var history: History
    var settings: Settings

    var centralManager: CBCentralManager
    var bluetoothDelegate: BluetoothDelegate
    var nfcReader: NFCReader
    var audioPlayer = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "alarm_high", ofType: "mp3")!), fileTypeHint: "mp3")
    var healthKit: HealthKit?
    var nightscout: Nightscout?
    var eventKit: EventKit?


    override init() {
        app = App()
        log = Log()
        history = History()
        settings = Settings()

        centralManager = CBCentralManager(delegate: nil, queue: nil)
        bluetoothDelegate = BluetoothDelegate()
        nfcReader = NFCReader()
        healthKit = HealthKit()

        super.init()

        log.text = "Welcome to DiaBLE!\n\(self.settings.logging ? "Log started" : "Log stopped") \(Date().local)\n"
        let userDefaults = UserDefaults.standard.dictionaryRepresentation()
        debugLog("User defaults: \(Settings.defaults.keys.map{ [$0, userDefaults[$0]!] }.sorted{($0[0] as! String) < ($1[0] as! String) })")

        bluetoothDelegate.main = self
        centralManager.delegate = bluetoothDelegate
        nfcReader.main = self

        if let healthKit = healthKit {
            healthKit.main = self
            healthKit.authorize() {
                self.log("HealthKit: \( $0 ? "" : "not ")authorized")
                if healthKit.isAuthorized {
                    healthKit.read() { self.debugLog("HealthKit last 12 stored values: \($0[..<(min(12, $0.count))])") }
                }
            }
        }

        nightscout = Nightscout(main: self)
        nightscout!.read()
        eventKit = EventKit(main: self)
        eventKit?.sync()


        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _,_ in }

        // FIXME: on Mac Catalyst: "Cannot activate session when app is in background."
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log("Audio Session error: \(error)")
        }

        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 8
        settings.numberFormatter = numberFormatter
    }


    public func log(_ text: String) {
        DispatchQueue.main.async {
            if self.settings.logging || text.hasPrefix("Log") {
                if self.settings.reversedLog {
                    self.log.text = "\(text)\n \n\(self.log.text)"
                } else {
                    self.log.text.append(" \n\(text)\n")
                }
            }
        }
        print("\(text)")
    }


    public func debugLog(_ text: String) {
        if settings.debugLevel > 0 {
            log(text)
        }
    }

    public func info(_ text: String) {
        DispatchQueue.main.async {
            if text.prefix(2) == "\n\n" {
                self.app.info = String(text.dropFirst(2))
            } else if !self.app.info.contains(text) {
                self.app.info.append(" \(text)")
            }
        }
    }

    public func playAlarm() {
        if !settings.mutedAudio {
            let currentGlucose = abs(app.currentGlucose)
            let soundName = currentGlucose > Int(settings.alarmHigh) ? "alarm_high" : "alarm_low"
            audioPlayer = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: soundName, ofType: "mp3")!), fileTypeHint: "mp3")
            audioPlayer.play()
            _ = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in self.audioPlayer.stop() }
            let times = currentGlucose > Int(settings.alarmHigh) ? 3 : 4
            let pause = times == 3 ? 1.0 : 5.0 / 6
            for s in 0 ..< times {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(s) * pause) {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            }
        }
    }


    func parseSensorData(_ sensor: Sensor) {

        log(sensor.crcReport)

        if sensor.crcReport.contains("FAILED") {
            if history.rawValues.count > 0 && sensor.type != .libre2 { // bogus raw data with Libre 1
                self.info("\nError while validating sensor data")
                return
            }
        }

        // TODO: Libre 2
        log("Sensor state: \(sensor.state)")

        if sensor.history.count > 0 {
            log("Sensor age: \(sensor.age) minutes (\(String(format: "%.2f", Double(sensor.age)/60/24)) days), started on: \((app.lastReadingDate - Double(sensor.age) * 60).shortDateTime)")

            history.rawTrend = sensor.trend
            log("Raw trend: \(sensor.trend.map{$0.value})")
            history.rawValues = sensor.history
            log("Raw history: \(sensor.history.map{$0.value})")

            if history.rawTrend.count > 0 {
                sensor.currentGlucose = -history.rawTrend[0].value
            }

            log("Sending sensor data to \(settings.oopServer.siteURL)/\(settings.oopServer.calibrationEndpoint)...")
            postToLibreOOP(server: settings.oopServer, bytes: sensor.fram, date: app.lastReadingDate) { data, response, error, parameters in
                self.debugLog("LibreOOP: query parameters: \(parameters)")
                if let data = data {
                    self.log("LibreOOP: server calibration response: \(data.string))")
                    let decoder = JSONDecoder.init()
                    if let oopCalibration = try? decoder.decode(OOPCalibrationResponse.self, from: data) {
                        if oopCalibration.parameters.offsetOffset == -2.0 &&
                            oopCalibration.parameters.slopeSlope  == 0.0 &&
                            oopCalibration.parameters.slopeOffset == 0.0 &&
                            oopCalibration.parameters.offsetSlope == 0.0 {
                            self.log("LibreOOP: null calibration")
                            self.info("\nLibreOOP calibration not valid")
                        } else {
                            self.app.calibration = oopCalibration.parameters
                            self.settings.oopCalibration = oopCalibration.parameters
                        }
                    }
                    
                } else {
                    self.log("LibreOOP: failed calibration")
                    self.info("\nLibreOOP calibration failed")
                }
                
                // Reapply the current calibration even when the connection fails
                self.applyCalibration(sensor: sensor)
                
                if sensor.patchInfo.count == 0 {
                    self.didParseSensor(sensor)
                }
                return
            }
        }

        debugLog("Sensor uid: \(sensor.uid.hex), saved uid:\(self.settings.patchUid.hex), patch info: \(sensor.patchInfo.hex.count > 0 ? sensor.patchInfo.hex : "<nil>"), saved patch info: \(self.settings.patchInfo.hex)")

        if sensor.uid.count > 0 && sensor.patchInfo.count > 0 {
            self.settings.patchUid = sensor.uid
            self.settings.patchInfo = sensor.patchInfo
        }

        if sensor.uid.count == 0 || self.settings.patchUid.count > 0 {
            if sensor.uid.count == 0 {
                sensor.uid = self.settings.patchUid
            }

            if sensor.uid == self.settings.patchUid {
                sensor.patchInfo = self.settings.patchInfo
            }
        }

        if sensor.patchInfo.count > 0 {
            log("Sending sensor data to \(settings.oopServer.siteURL)/\(settings.oopServer.historyEndpoint)...")

            postToLibreOOP(server: settings.oopServer, bytes: sensor.fram, date: app.lastReadingDate, patchUid: sensor.uid, patchInfo: sensor.patchInfo) { data, response, error, parameters in
                self.debugLog("LibreOOP: query parameters: \(parameters)")
                if let data = data {
                    self.log("LibreOOP: server history response: \(data.string)")
                    if data.string.contains("errcode") {
                        self.info("\n\(data.string)")
                        self.history.values = []
                    } else {
                        let decoder = JSONDecoder.init()
                        if let oopData = try? decoder.decode(OOPHistoryData.self, from: data) {
                            let realTimeGlucose = oopData.realTimeGlucose.value
                            if realTimeGlucose > 0 {
                                sensor.currentGlucose = realTimeGlucose
                            }
                            // PROJECTED_HIGH_GLUCOSE | HIGH_GLUCOSE | GLUCOSE_OK | LOW_GLUCOSE | PROJECTED_LOW_GLUCOSE | NOT_DETERMINED
                            self.app.oopAlarm = oopData.alarm
                            // FALLING_QUICKLY | FALLING | STABLE | RISING | RISING_QUICKLY | NOT_DETERMINED
                            self.app.oopTrend = oopData.trendArrow
                            var oopHistory = oopData.glucoseData(sensorAge: sensor.age, readingDate: self.app.lastReadingDate)
                            let oopHistoryCount = oopHistory.count
                            if oopHistoryCount > 1 && self.history.rawValues.count > 0 {
                                if oopHistory[0].value == 0 && oopHistory[1].id == self.history.rawValues[0].id {
                                    oopHistory.removeFirst()
                                    self.debugLog("LibreOOP: dropped the first null OOP value newer than the corresponding raw one")
                                }
                            }
                            if oopHistoryCount > 0 {
                                if oopHistoryCount < 32 { // new sensor
                                    oopHistory.append(contentsOf: [Glucose](repeating: Glucose(-1), count: 32 - oopHistoryCount))
                                }
                                self.history.values = oopHistory
                            } else {
                                self.history.values = []
                            }
                            self.log("LibreOOP: history values: \(oopHistory.map{ $0.value })")
                        } else {
                            self.log("LibreOOP: error decoding JSON data")
                            self.info("\nLibreOOP server error: \(data.string)")
                        }
                    }
                } else {
                    self.history.values = []
                    self.log("LibreOOP: connection failed")
                    self.info("\nLibreOOP connection failed")
                }
                self.didParseSensor(sensor)
                return
            }
        } else {
            self.info("\nPatch info not available")
            return
        }
    }


    func applyCalibration(sensor: Sensor) {
        if self.app.calibration.offsetOffset != 0.0 && sensor.history.count > 0 {

            var calibratedTrend = sensor.trend
            for i in 0 ..< calibratedTrend.count {
                calibratedTrend[i].calibration = self.app.calibration
            }

            var calibratedHistory = sensor.history
            for i in 0 ..< calibratedHistory.count {
                calibratedHistory[i].calibration = self.app.calibration
            }

            self.history.calibratedTrend = calibratedTrend
            self.history.calibratedValues = calibratedHistory
            sensor.currentGlucose = -self.history.calibratedTrend[0].value
        }
    }

    /// currentGlucose is negative when set to the last trend raw value (no online connection)
    func didParseSensor(_ sensor: Sensor) {

        var currentGlucose = sensor.currentGlucose

        app.currentGlucose = currentGlucose

        var title = currentGlucose > 0 ?
            "\(currentGlucose)" :
            (currentGlucose < 0 ?
                "(\(-currentGlucose))" : "---")

        currentGlucose = abs(currentGlucose)

        if currentGlucose > 0 && (currentGlucose > Int(settings.alarmHigh) || currentGlucose < Int(settings.alarmLow)) {
            log("ALARM: current glucose: \(currentGlucose) (settings: high: \(Int(settings.alarmHigh)), low: \(Int(settings.alarmLow)))")
            playAlarm()
            if (settings.calendarTitle == "" || !settings.calendarAlarmIsOn) && !settings.disabledNotifications { // TODO: notifications settings
                title += "  \(settings.glucoseUnit)"
                title += "  \(OOP.alarmDescription(for: app.oopAlarm))  \(OOP.trendSymbol(for: app.oopTrend))"
                let content = UNMutableNotificationContent()
                content.title = title
                content.subtitle = ""
                content.sound = UNNotificationSound.default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: "DiaBLE", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }

        if !settings.disabledNotifications {
            UIApplication.shared.applicationIconBadgeNumber = currentGlucose
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }

        eventKit?.sync()

        if history.values.count > 0 {
            let entries = (self.history.values + [Glucose(currentGlucose, date: sensor.lastReadingDate, source: "DiaBLE")]).filter{ $0.value > 0 }

            // TODO
            healthKit?.write(entries.filter{$0.date > healthKit?.lastDate ?? Calendar.current.date(byAdding: .hour, value: -8, to : Date())!})

            nightscout?.delete(query: "find[device]=LibreOOP&count=32") { data, response, error in
                self.nightscout?.post(entries: entries) { data, response, error in
                    self.nightscout?.read()
                }
            }
        }
    }
}
