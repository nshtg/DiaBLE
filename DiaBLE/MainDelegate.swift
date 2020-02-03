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

        log.text = "\(self.settings.logging ? "Log started" : "Log stopped") \(Date().local)\n"
        let userDefaults = UserDefaults.standard.dictionaryRepresentation()
        if settings.debugLevel > 0 { log("User defaults: \(Settings.defaults.keys.map{ [$0, userDefaults[$0]!] }.sorted{($0[0] as! String) < ($1[0] as! String) })") }

        bluetoothDelegate.main = self
        centralManager.delegate = bluetoothDelegate
        nfcReader.main = self

        if let healthKit = healthKit {
            healthKit.main = self
            healthKit.authorize() {
                self.log("HealthKit: \( $0 ? "" : "not ")authorized")
                if healthKit.isAuthorized {
                    healthKit.read() { if self.settings.debugLevel > 0 { self.log("HealthKit last 12 stored values: \($0[..<12])") } }
                }
            }
        }

        nightscout = Nightscout(NightscoutServer(siteURL: settings.nightscoutSite, token: settings.nightscoutToken))
        nightscout!.main = self
        nightscout!.read()

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
            audioPlayer.currentTime = 25.0
            audioPlayer.play()
        }
        for s in 0...2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(s)) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }


    func parseSensorData(_ sensor: Sensor) {

        log(sensor.crcReport)
        log("Sensor state: \(sensor.state)")
        log("Sensor age: \(sensor.age) minutes (\(String(format: "%.2f", Double(sensor.age)/60/24)) days), started on: \((app.lastReadingDate - Double(sensor.age) * 60).shortDateTime)")

        history.rawTrend = sensor.trend
        log("Raw trend: \(sensor.trend.map{$0.value})")
        history.rawValues = sensor.history
        log("Raw history: \(sensor.history.map{$0.value})")

        sensor.currentGlucose = -history.rawTrend[0].value

        log("Sending sensor data to \(settings.oopServer.siteURL)\(settings.oopServer.calibrationEndpoint)...")
        postToLibreOOP(server: settings.oopServer, bytes: sensor.fram, date: app.lastReadingDate) { data, response, error, parameters in
            if self.settings.debugLevel > 0 { self.log("LibreOOP: query parameters: \(parameters)") }
            if let data = data {
                let json = data.string
                self.log("LibreOOP server calibration response: \(json))")
                let decoder = JSONDecoder.init()
                if let oopCalibration = try? decoder.decode(OOPCalibrationResponse.self, from: data) {
                    self.app.calibration = oopCalibration.parameters
                }

            } else {
                self.log("LibreOOP: failed calibration")
                self.info("\nLibreOOP calibration failed")
            }

            // Reapply the current calibration even when the connection fails

            if self.app.calibration.offsetOffset != 0.0 {

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


            if sensor.patchInfo.count == 0 {
                self.didParseSensor(sensor)
            }
            return
        }

        if sensor.patchInfo.count > 0 {
            log("Sending sensor data to \(settings.oopServer.siteURL)\(settings.oopServer.historyEndpoint)...")

            postToLibreOOP(server: settings.oopServer, bytes: sensor.fram, date: app.lastReadingDate, patchUid: sensor.uid, patchInfo: sensor.patchInfo) { data, response, error, parameters in
                if self.settings.debugLevel > 0 { self.log("LibreOOP: query parameters: \(parameters)") }
                if let data = data {
                    let json = data.string
                    self.log("LibreOOP server history response: \(json)")
                    if json.contains("errcode") {
                        self.info("\n\(json)")
                        self.log("LibreOOP: failed getting history")
                        self.info("\nLibreOOP: failed getting historic data")
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
                            if oopHistory[0].value == 0 && oopHistory[1].id == self.history.rawValues[0].id {
                                oopHistory.removeFirst()
                                if self.settings.debugLevel > 0 { self.log("DEBUG: dropped the first null OOP value newer than the corresponding raw one") }
                            }
                            let oopHistoryCount = oopHistory.count
                            if oopHistoryCount > 0 {
                                if oopHistoryCount < 32 { // new sensor
                                    oopHistory.append(contentsOf: [Glucose](repeating: Glucose(-1), count: 32 - oopHistoryCount))
                                }
                                self.history.values = oopHistory
                            } else {
                                self.history.values = []
                            }
                            self.log("OOP history: \(oopHistory.map{ $0.value })")
                        } else {
                            self.log("Missing LibreOOP data")
                            self.info("\nMissing LibreOOP data")
                        }
                    }
                } else {
                    self.history.values = []
                    self.log("LibreOOP connection failed")
                    self.info("\nLibreOOP connection failed")
                }
                self.didParseSensor(sensor)
                return
            }
        }
    }


    /// currentGlucose is negative when set to the last trend raw value (no online connection)
    func didParseSensor(_ sensor: Sensor) {

        var currentGlucose = sensor.currentGlucose

        app.currentGlucose = currentGlucose

        currentGlucose = abs(currentGlucose)

        if currentGlucose > 0 && (currentGlucose > Int(settings.alarmHigh) || currentGlucose < Int(settings.alarmLow)) {
            log("ALARM: current glucose: \(currentGlucose) (settings: high: \(Int(settings.alarmHigh)), low: \(Int(settings.alarmLow)))")
            playAlarm()
        }

        UIApplication.shared.applicationIconBadgeNumber = currentGlucose

        if history.values.count > 0 {
            nightscout?.post(Glucose(currentGlucose, date: sensor.lastReadingDate)) { data, response, error in
                self.nightscout?.read()
            }
            // TODO: post all history values
        }
    }
}
