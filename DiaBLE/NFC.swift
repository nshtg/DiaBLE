import Foundation
import CoreNFC


// https://github.com/travisgoodspeed/goodtag/wiki/RF430TAL152H
// https://github.com/travisgoodspeed/GoodV/blob/master/app/src/main/java/com/kk4vcz/goodv/NfcRF430TAL.java
// https://github.com/travisgoodspeed/goodtag/blob/master/firmware/gcmpatch.c
//
// "The Inner Guts of a Connected Glucose Sensor for Diabetes"
// https://www.youtube.com/watch?v=Y9vtGmxh1IQ
// https://github.com/cryptax/talks/blob/master/BlackAlps-2019/glucose-blackalps2019.pdf
// https://github.com/cryptax/misc-code/blob/master/glucose-tools/readdump.py
//
// "NFC Exploitation with the RF430RFL152 and 'TAL152" in PoC||GTFO 0x20
// https://archive.org/stream/pocorgtfo20#page/n6/mode/1up


extension SensorType {
    var backdoor: String {
        switch self {
        case .libre1:    return "c2ad7521"
        default:         return "deadbeef"
        }
    }
}


class NFCReader: NSObject, NFCTagReaderSessionDelegate {

    var tagSession: NFCTagReaderSession?
    var connectedTag: NFCISO15693Tag?
    var sensor: Sensor!

    /// Main app delegate to use its log()
    var main: MainDelegate!

    var isNFCAvailable: Bool {
        return NFCTagReaderSession.readingAvailable
    }

    func startSession() {
        // execute in the .main queue because of publishing changes to main's observables
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
            self.connectedTag = tag

            // https://www.st.com/en/embedded-software/stsw-st25ios001.html#get-software

            self.connectedTag?.getSystemInfo(requestFlags: [.address, .highDataRate]) { (dfsid: Int, afi: Int, blockSize: Int, memorySize: Int, icRef: Int, error: Error?) in
                if error != nil {
                    session.invalidate(errorMessage: "Error while getting system info: " + error!.localizedDescription)
                    self.main.log("NFC: error while getting system info: \(error!.localizedDescription)")
                    return
                }

                self.connectedTag?.customCommand(requestFlags: [.highDataRate], customCommandCode: 0xA1, customRequestParameters: Data()) { (customResponse: Data, error: Error?) in
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

                                if self.main.settings.debugLevel == 0 {
                                    session.invalidate()
                                }

                                if  self.main.app.sensor != nil {
                                    self.sensor = self.main.app.sensor
                                } else {
                                    self.sensor = Sensor()
                                    self.main.app.sensor = self.sensor
                                }

                                var fram = Data()

                                self.main.app.lastReadingDate = Date()
                                self.sensor.lastReadingDate = self.main.app.lastReadingDate

                                var msg = ""
                                for (n, data) in dataArray.enumerated() {
                                    if data.count > 0 {
                                        fram.append(data)
                                        msg += "NFC block #\(String(format:"%02d", n)): \(data.reduce("", { $0 + String(format: "%02X", $1) + " "}).dropLast())\n"
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

                                self.sensor.uid = Data(tag.identifier.reversed())
                                self.main.log("NFC: sensor uid: \(self.sensor.uid.hex)")
                                self.main.log("NFC: sensor serial number: \(self.sensor.serial)")

                                let patchInfo = customResponse
                                self.sensor.patchInfo = Data(patchInfo)
                                if customResponse.count > 0 {
                                    self.main.log("NFC: patch info: \(patchInfo.hex)")
                                    self.main.log("NFC: sensor type: \(self.sensor.type.rawValue)")

                                    self.main.settings.patchUid = self.sensor.uid
                                    self.main.settings.patchInfo = self.sensor.patchInfo
                                }

                                self.main.status("\(self.sensor.type)  +  NFC")

                                if self.main.settings.debugLevel > 0 {
                                    let msg = "NFC: dump of "
                                    self.readRaw(0xF860, 43 * 8) { self.main.debugLog(msg + ($2?.localizedDescription ?? $1.hexDump(address: Int($0), header: "FRAM:")))
                                        self.readRaw(0x1A00, 64) { self.main.debugLog(msg + ($2?.localizedDescription ?? $1.hexDump(address: Int($0), header: "config RAM\n(patchUid at 0x1A08):")))
                                            self.readRaw(0xFFB8, 24) { self.main.debugLog(msg + ($2?.localizedDescription ?? $1.hexDump(address: Int($0), header: "patch table for A0-A4 commands:")))
                                                session.invalidate()

                                                // same final code as for debugLevel = 0

                                                if fram.count > 0 {
                                                    self.sensor.fram = Data(fram)
                                                }
                                                self.main.parseSensorData(self.sensor)
                                            }
                                        }
                                    }
                                } else {

                                    // same final code as for debugLevel > 0

                                    if fram.count > 0 {
                                        self.sensor.fram = Data(fram)
                                    }
                                    self.main.parseSensorData(self.sensor)
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    /// fram:   0xF800, 2048
    /// rom:    0x4400, 0x2000
    /// sram:   0x1C00, 0x1000
    /// config: 0x1A00, 64    (serial number and calibration)

    func readRaw(_ address: UInt16, _ bytes: Int, buffer: Data = Data(), handler: @escaping (UInt16, Data, Error?) -> Void) {

        var buffer = buffer
        let addressToRead = address + UInt16(buffer.count)

        var remainingBytes = bytes
        let bytesToRead = remainingBytes > 24 ? 24 : bytes

        var remainingWords = bytes / 2
        if bytes % 2 == 1 || ( bytes % 2 == 0 && addressToRead % 2 == 1 ) { remainingWords += 1 }
        let wordsToRead = UInt8(remainingWords > 12 ? 12 : remainingWords)    // real limit is 15

        self.connectedTag?.customCommand(requestFlags: [.highDataRate], customCommandCode: 0xA3, customRequestParameters: Data(self.sensor.type.backdoor.bytes + [UInt8(addressToRead & 0x00FF), UInt8(addressToRead >> 8), wordsToRead])) { (customResponse: Data, error: Error?) in

            var data = customResponse

            if error != nil {
                self.main.log("NFC: error while reading \(wordsToRead) words at raw memory 0x\(String(format: "%04X", addressToRead))")
                remainingBytes = 0
            } else {
                if addressToRead % 2 == 1 { data = data.subdata(in: 1 ..< data.count) }
                if data.count - Int(bytesToRead) == 1 { data = data.subdata(in: 0 ..< data.count - 1) }
            }

            buffer += data
            remainingBytes -= data.count

            if remainingBytes == 0 {
                handler(address, buffer, error)
            } else {
                self.readRaw(address, remainingBytes, buffer: buffer) { address, data, error in handler(address, data, error) }
            }
        }
    }

}
