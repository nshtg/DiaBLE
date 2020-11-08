import SwiftUI
import CoreBluetooth
import AVFoundation


public class MainDelegate: NSObject, UIApplicationDelegate, UIWindowSceneDelegate, UNUserNotificationCenterDelegate {

    var app: AppState
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

        UserDefaults.standard.register(defaults: Settings.defaults)

        app = AppState()
        log = Log()
        history = History()
        settings = Settings()

        centralManager = CBCentralManager(delegate: nil, queue: nil)
        bluetoothDelegate = BluetoothDelegate()
        nfcReader = NFCReader()
        healthKit = HealthKit()

        super.init()

        log.text = "Welcome to DiaBLE!\n\(settings.logging ? "Log started" : "Log stopped") \(Date().local)\n"
        debugLog("User defaults: \(Settings.defaults.keys.map{ [$0, UserDefaults.standard.dictionaryRepresentation()[$0]!] }.sorted{($0[0] as! String) < ($1[0] as! String) })")

        app.main = self
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


    public func log(_ msg: String) {
        DispatchQueue.main.async {
            if self.settings.logging || msg.hasPrefix("Log") {
                if self.settings.reversedLog {
                    self.log.text = "\(msg)\n \n\(self.log.text)"
                } else {
                    self.log.text.append(" \n\(msg)\n")
                }
            }
        }
        print(msg)
    }


    public func debugLog(_ msg: String) {
        if settings.debugLevel > 0 {
            log(msg)
        }
    }

    public func status(_ text: String) {
        DispatchQueue.main.async {
            self.app.status = text
        }
    }

    public func errorStatus(_ text: String) {
        if !self.app.status.contains(text) {
            DispatchQueue.main.async {
                self.app.status.append("\n\(text)")
            }
        }
    }


    // FIXME: iOS 14: launchOptions empty
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            if shortcutItem.type == "NFC" {
                if nfcReader.isNFCAvailable {
                    nfcReader.startSession()
                }
            }
        }
        return true
    }

    public func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfiguration = UISceneConfiguration(name: "LaunchConfiguration", sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = MainDelegate.self
        return sceneConfiguration
    }

    public func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "NFC" {
            if nfcReader.isNFCAvailable {
                nfcReader.startSession()
            }
        }
        completionHandler(true)
    }


    public func playAlarm() {
        let currentGlucose = abs(app.currentGlucose)
        if !settings.mutedAudio {
            let soundName = currentGlucose > Int(settings.alarmHigh) ? "alarm_high" : "alarm_low"
            audioPlayer = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: soundName, ofType: "mp3")!), fileTypeHint: "mp3")
            audioPlayer.play()
            _ = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in self.audioPlayer.stop() }
        }
        if !settings.disabledNotifications {
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

        if sensor.encryptedFram.count > 0 {
            log("Sensor encrypted FRAM: \(sensor.encryptedFram.hex)\ndecrypted:\n\(sensor.fram.hex)")
        }
        log(sensor.crcReport)
        if sensor.crcReport.contains("FAILED") {
            if history.rawValues.count > 0 && sensor.type != .libre2 { // bogus raw data with Libre 1
                self.errorStatus("Error while validating sensor data")
                return
            }
        }

        log("Sensor state: \(sensor.state)")
        if sensor.reinitializations > 0 { log("Sensor reinitializations: \(sensor.reinitializations)") }
        log("Sensor region: \(SensorRegion(rawValue: sensor.region)?.description ?? "unknown")\(sensor.region != 0 ? " (0x" + String(format: "%02X", sensor.region) + ")" : "")")
        if sensor.maxLife > 0 { log("Sensor maximum life: \(String(format: "%.2f", Double(sensor.maxLife)/60/24)) days (\(sensor.maxLife) minutes)") }

        if sensor.history.count > 0 && sensor.fram.count >= 344 {

            log("Sensor age: \(sensor.age) minutes (\(String(format: "%.2f", Double(sensor.age)/60/24)) days), started on: \((app.lastReadingDate - Double(sensor.age) * 60).shortDateTime)")

            let calibrationInfo = sensor.calibrationInfo
            if sensor.serial == settings.activeSensorSerial {
                settings.activeSensorCalibrationInfo = calibrationInfo
            }

            history.rawTrend = sensor.trend
            log("Raw trend: \(sensor.trend.map{$0.raw})")
            debugLog("Raw trend temperatures: \(sensor.trend.map{$0.rawTemperature})")
            let factoryTrend = sensor.trend.map { factoryGlucose(raw: $0, calibrationInfo: calibrationInfo) }
            history.factoryTrend = factoryTrend
            log("Factory trend: \(factoryTrend.map{$0.value})")
            log("Trend temperatures: \(factoryTrend.map{Double(String(format: "%.1f", $0.temperature))!}))")
            history.rawValues = sensor.history
            log("Raw history: \(sensor.history.map{$0.raw})")
            debugLog("Raw historic temperatures: \(sensor.history.map{$0.rawTemperature})")
            let factoryHistory = sensor.history.map { factoryGlucose(raw: $0, calibrationInfo: calibrationInfo) }
            history.factoryValues = factoryHistory
            log("Factory history: \(factoryHistory.map{$0.value})")
            log("Historic temperatures: \(factoryHistory.map{Double(String(format: "%.1f", $0.temperature))!})")

            if history.rawTrend.count > 0 {
                sensor.currentGlucose = -history.rawTrend[0].value
            }

            log("Sending sensor data to \(settings.oopServer.siteURL)/\(settings.oopServer.calibrationEndpoint)...")
            postToOOP(server: settings.oopServer, bytes: sensor.fram, date: app.lastReadingDate) { data, response, error, queryItems in
                self.debugLog("OOP: query parameters: \(queryItems)")
                if let data = data {
                    self.log("OOP: server calibration response: \(data.string)")
                    let decoder = JSONDecoder()
                    if let oopCalibration = try? decoder.decode(OOPCalibrationResponse.self, from: data) {
                        if oopCalibration.parameters.offsetOffset == -2.0 &&
                            oopCalibration.parameters.slopeSlope  == 0.0 &&
                            oopCalibration.parameters.slopeOffset == 0.0 &&
                            oopCalibration.parameters.offsetSlope == 0.0 {
                            self.log("OOP: null calibration")
                            self.errorStatus("OOP calibration not valid")
                        } else {
                            self.settings.oopCalibration = oopCalibration.parameters
                            if self.app.calibration == Calibration() || (self.app.calibration != self.settings.calibration) {
                                self.app.calibration = oopCalibration.parameters
                            }
                        }
                    } else {
                        if data.string.contains("errcode") {
                            self.errorStatus("OOP calibration error: \(data.string)")
                        }
                    }

                } else {
                    self.log("OOP: failed calibration")
                    self.errorStatus("OOP calibration failed")
                }

                // Reapply the current calibration even when the connection fails
                self.applyCalibration(sensor: sensor)

                if sensor.patchInfo.count == 0 {
                    self.didParseSensor(sensor)
                }
                return
            }
        }

        debugLog("Sensor uid: \(sensor.uid.hex), saved uid:\(settings.patchUid.hex), patch info: \(sensor.patchInfo.hex.count > 0 ? sensor.patchInfo.hex : "<nil>"), saved patch info: \(settings.patchInfo.hex)")

        if sensor.uid.count > 0 && sensor.patchInfo.count > 0 {
            settings.patchUid = sensor.uid
            settings.patchInfo = sensor.patchInfo
        }

        if sensor.uid.count == 0 || settings.patchUid.count > 0 {
            if sensor.uid.count == 0 {
                sensor.uid = settings.patchUid
            }

            if sensor.uid == settings.patchUid {
                sensor.patchInfo = settings.patchInfo
            }
        }

        if sensor.patchInfo.count > 0 {

            // TODO
            if settings.debugLevel > 0 {
                debugLog("Sending sensor data to \(settings.oopServer.siteURL)/\(settings.oopServer.activationEndpoint)...")
                postToOOP(server: settings.oopServer, patchUid: sensor.uid, patchInfo: sensor.patchInfo) { data, response, error, queryItems in
                    self.debugLog("OOP: query parameters: \(queryItems)")
                    if let data = data {
                        self.debugLog("OOP: server activation response: \(data.string)")
                        let decoder = JSONDecoder()
                        if let oopActivationResponse = try? decoder.decode(GlucoseSpaceActivationResponse.self, from: data) {
                            self.debugLog("OOP: activation response: \(oopActivationResponse), activation command: 0x\(String(format: "%2X", UInt8(Int16(oopActivationResponse.activationCommand) & 0xFF)))")
                        }
                        if sensor.type == .libre2 {
                            self.debugLog("Libre 2: computed activation payload: \(sensor.nfcCommand(.activate).parameters.hex)" )
                        }
                    }
                }
            }

            var fram = sensor.encryptedFram.count > 0 ? sensor.encryptedFram : sensor.fram

            guard fram.count >= 344 else {
                log("Partially scanned FRAM (\(fram.count)/344): cannot proceed to OOP")
                return
            }

            // decryptFRAM() is symmetric: encrypt decrypted fram received from a Bubble
            if (sensor.type == .libre2 || sensor.type == .libreUS14day) && sensor.encryptedFram.count == 0 {
                fram = try! Data(Libre2.decryptFRAM(type: sensor.type, id: sensor.uid, info: sensor.patchInfo, data: fram))
            }

            log("Sending sensor data to \(settings.oopServer.siteURL)/\(settings.oopServer.historyEndpoint)...")

            postToOOP(server: settings.oopServer, bytes: fram, date: app.lastReadingDate, patchUid: sensor.uid, patchInfo: sensor.patchInfo) { data, response, error, parameters in
                self.debugLog("OOP: query parameters: \(parameters)")
                if let data = data {
                    self.log("OOP: server history response: \(data.string)")
                    if data.string.contains("errcode") {
                        self.errorStatus("OOP history error: \(data.string)")
                        self.history.values = []
                    } else {
                        let decoder = JSONDecoder()
                        if let oopData = try? decoder.decode(GlucoseSpaceHistoryResponse.self, from: data) {
                            let realTimeGlucose = oopData.realTimeGlucose.value
                            if realTimeGlucose > 0 {
                                sensor.currentGlucose = realTimeGlucose
                            }
                            // PROJECTED_HIGH_GLUCOSE | HIGH_GLUCOSE | GLUCOSE_OK | LOW_GLUCOSE | PROJECTED_LOW_GLUCOSE | NOT_DETERMINED
                            self.app.oopAlarm = oopData.alarm ?? ""
                            // FALLING_QUICKLY | FALLING | STABLE | RISING | RISING_QUICKLY | NOT_DETERMINED
                            self.app.oopTrend = oopData.trendArrow ?? ""
                            var oopHistory = oopData.glucoseData(sensorAge: sensor.age, readingDate: self.app.lastReadingDate)
                            let oopHistoryCount = oopHistory.count
                            if oopHistoryCount > 1 && self.history.rawValues.count > 0 {
                                if oopHistory[0].value == 0 && oopHistory[1].id == self.history.rawValues[0].id {
                                    oopHistory.removeFirst()
                                    self.debugLog("OOP: dropped the first null OOP value newer than the corresponding raw one")
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
                            self.log("OOP: history values: \(oopHistory.map{ $0.value })")
                        } else {
                            self.log("OOP: error while decoding JSON data")
                            self.errorStatus("OOP server error: \(data.string)")
                        }
                    }
                } else {
                    self.history.values = []
                    self.log("OOP: connection failed")
                    self.errorStatus("OOP connection failed")
                }
                self.didParseSensor(sensor)
                return
            }
        } else {
            self.errorStatus("Patch info not available")
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
                title += "  \(OOP.Alarm(rawValue: app.oopAlarm)?.description ?? "")  \(OOP.TrendArrow(rawValue: app.oopTrend)?.symbol ?? "---")"
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

        if history.values.count > 0 || history.factoryValues.count > 0 {
            let entries = (self.history.values + [Glucose(currentGlucose, date: sensor.lastReadingDate, source: "DiaBLE")]).filter{ $0.value > 0 }

            // TODO
            healthKit?.write(entries.filter{$0.date > healthKit?.lastDate ?? Calendar.current.date(byAdding: .hour, value: -8, to: Date())!})
            healthKit?.read()

            nightscout?.delete(query: "find[device]=OOP&count=32") { data, response, error in
                self.nightscout?.post(entries: entries) { data, response, error in
                    self.nightscout?.read()
                }
            }
        }
    }
}
