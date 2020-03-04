import Foundation
import CoreNFC

class NFCReader: NSObject, NFCTagReaderSessionDelegate {

    var tagSession: NFCTagReaderSession?

    /// Main app delegate to use its log()
    var main: MainDelegate!

    var isNFCAvailable: Bool {
        return NFCTagReaderSession.readingAvailable
    }
    
    func startSession() {
        // execute in the .main queue because of main.log
        tagSession = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: .main)
        tagSession?.alertMessage = "Hold the top of your iPhone near the Libre sensor"
        tagSession?.begin()
    }

    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        main.log("NFC: session did become active")
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            if readerError.code != .readerSessionInvalidationErrorUserCanceled {
                main.log("NFC: \(readerError.localizedDescription)")
                session.invalidate(errorMessage: "Connection failure: \(readerError.localizedDescription)")
            }
        }
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        main.log("NFC: did detect tags")

        guard let firstTag = tags.first else { return }
        guard case .iso15693(let tag) = firstTag else { return }

        session.alertMessage = "Scan complete"

        let blocks = 43
        let requestBlocks = 3

        let requests = Int(ceil(Double(blocks) / Double(requestBlocks)))
        let remainder = blocks % requestBlocks
        var dataArray = [Data](repeating: Data(), count: blocks)

        session.connect(to: firstTag) { error in
            if error != nil {
                self.main.log("NFC: \(error!.localizedDescription)")
                session.invalidate(errorMessage: "Connection failure: \(error!.localizedDescription)")
                return
            }

            // https://www.st.com/en/embedded-software/stsw-st25ios001.html#get-software

            tag.getSystemInfo(requestFlags: [.address, .highDataRate]) { (dfsid: Int, afi: Int, blockSize: Int, memorySize: Int, icRef: Int, error: Error?) in
                if error != nil {
                    session.invalidate(errorMessage: "Error while getting system info: " + error!.localizedDescription)
                    self.main.log("NFC: error while getting system info: \(error!.localizedDescription)")
                    return
                }

                // https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/NFCReaderX.java

                tag.customCommand(requestFlags: RequestFlag(rawValue: 0x02), customCommandCode: 0xA1, customRequestParameters: Data([0x07])) { (customResponse: Data, error: Error?) in
                    if error != nil {
                        // session.invalidate(errorMessage: "Error while getting patch info: " + error!.localizedDescription)
                        self.main.log("NFC: error while getting patch info: \(error!.localizedDescription)")
                    }

                    for i in 0 ..< requests {

                        tag.readMultipleBlocks(requestFlags: [.highDataRate, .address], blockRange: NSRange(UInt8(i * requestBlocks)...UInt8(i * requestBlocks + (i == requests - 1 ? remainder - 1: requestBlocks - 1)))) { (blockArray, error) in

                            if error != nil {
                                self.main.log("NFC: error while reading multiple blocks (#\(i * requestBlocks) - #\(i * requestBlocks + (i == requests - 1 ? remainder - 1: requestBlocks - 1))) : \(error!.localizedDescription)")
                                session.invalidate(errorMessage: "Error while reading multiple blocks: \(error!.localizedDescription)")
                                if i != requests - 1 { return }

                            } else {
                                for j in 0 ..< blockArray.count {
                                    dataArray[i * requestBlocks + j] = blockArray[j]
                                }
                            }


                            if i == requests - 1 {

                                session.invalidate()

                                var sensor: Sensor
                                if  self.main.app.sensor != nil {
                                    sensor = self.main.app.sensor
                                } else {
                                    sensor = Sensor()
                                    self.main.app.sensor = sensor
                                }

                                var fram = Data()

                                self.main.app.lastReadingDate = Date()
                                sensor.lastReadingDate = self.main.app.lastReadingDate

                                var msg = ""
                                for (n, data) in dataArray.enumerated() {
                                    if data.count > 0 {
                                        fram.append(data)
                                        msg += "NFC block #\(String(format:"%02d", n)): \(data.reduce("", { $0 + String(format: "%02X", $1) + " "}))\n"
                                    }
                                }
                                if !msg.isEmpty { self.main.log(String(msg.dropLast())) }

                                let uid = tag.identifier.hex
                                self.main.log("NFC: IC identifier: \(uid)")

                                var manufacturer = String(tag.icManufacturerCode)
                                if manufacturer == "7" {
                                    manufacturer.append(" (Texas Instruments)")
                                }
                                self.main.log("NFC: IC manufacturer code: \(manufacturer)")
                                self.main.log("NFC: IC serial number: \(tag.icSerialNumber.hex)")

                                self.main.log(String(format: "NFC: IC reference: 0x%X", icRef))

                                self.main.log(String(format: "NFC: block size: %d", blockSize))
                                self.main.log(String(format: "NFC: memory size: %d blocks", memorySize))

                                sensor.uid = Data(tag.identifier.reversed())
                                self.main.log("NFC: sensor uid: \(sensor.uid.hex)")
                                self.main.log("NFC: sensor serial number: \(sensor.serial)")

                                if customResponse.count > 0 {
                                    let patchInfo = customResponse
                                    sensor.patchInfo = Data(patchInfo)
                                    self.main.log("NFC: patch info: \(patchInfo.hex)")
                                    self.main.log("NFC: Libre type: \(sensor.type.rawValue)")

                                    self.main.settings.patchUid = sensor.uid
                                    self.main.settings.patchInfo = sensor.patchInfo
                                }

                                if fram.count > 0 {
                                    sensor.fram = Data(fram)
                                }

                                self.main.info("\n\n\(sensor.type) + NFC")
                                self.main.parseSensorData(sensor)
                            }
                        }
                    }
                }
            }
        }
    }
}
