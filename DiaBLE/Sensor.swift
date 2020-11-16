import Foundation


typealias SensorUid = Data
typealias PatchInfo = Data


enum SensorType: String, CustomStringConvertible {
    case libre1       = "Libre 1"
    case libre2       = "Libre 2"
    case libreUS14day = "Libre US 14d"
    case libreProH    = "Libre Pro/H"
    case unknown      = "Libre"

    var description: String { self.rawValue }

    var serialPrefix: String {    // equals product family
        switch self {
        case .libreProH: return "1"
        case .libre2:    return "3"
        default:         return "0"
        }
    }
}


func sensorType(patchInfo: PatchInfo) -> SensorType {
    switch patchInfo[0] {
    case 0xDF: return .libre1
    case 0xA2: return .libre1
    case 0x9D: return .libre2
    case 0xE5: return .libreUS14day
    case 0x70: return .libreProH
    default:   return .unknown
    }
}


enum SensorRegion: Int, CustomStringConvertible {
    case unknown    = 0
    case european   = 1
    case usa        = 2
    case australian = 4
    case eastern    = 8

    var description: String {
        switch self {
        case .unknown:    return "unknown"
        case .european:   return "European"
        case .usa:        return "USA"
        case .australian: return "Australian"
        case .eastern:    return "Eastern"
        }
    }
}


enum SensorState: UInt8, CustomStringConvertible {
    case unknown      = 0x00
    
    case notActivated = 0x01
    case warmingUp    = 0x02
    case active       = 0x03    // Libre 1: for ≈ 14.5 days
    case expired      = 0x04    // Libre 1: 12 hours more
    case shutdown     = 0x05    // Libre 1: 15th day onwards
    case failure      = 0x06

    var description: String {
        switch self {
        case .notActivated: return "Not activated"
        case .warmingUp:    return "Warming up"
        case .active:       return "Active"
        case .expired:      return "Expired"
        case .shutdown:     return "Shut down"
        case .failure:      return "Failure"
        default:            return "Unknown"
        }
    }
}

struct CalibrationInfo: Codable, Equatable {
   var i1: Int = 0
   var i2: Int = 0
   var i3: Int = 0
   var i4: Int = 0
   var i5: Int = 0
   var i6: Int = 0
 }


class Sensor: ObservableObject {

    var type: SensorType = .unknown
    var region: Int = 0
    var serial: String = ""

    @Published var transmitter: Transmitter?
    @Published var state: SensorState = .unknown
    @Published var currentGlucose: Int = 0
    @Published var lastReadingDate = Date()
    @Published var age: Int = 0
    @Published var maxLife: Int = 0
    @Published var reinitializations: Int = 0

    var crcReport: String = ""    // TODO


    var patchInfo: PatchInfo = Data() {
        willSet(info) {
            if info.count > 0 {
                type = sensorType(patchInfo: info)
            } else {
                type = .unknown
            }
            if serial != "" {
                serial = type.serialPrefix + serial.dropFirst()
            }
            if region == 0 && info.count > 3 {
                region = Int(info[3])
            }
        }
    }

    var uid: SensorUid = Data() {
        willSet(uid) {
            serial = serialNumber(uid: uid)
        }
    }

    var trend: [Glucose] = []
    var history: [Glucose] = []

    var fram: Data = Data() {
        didSet {
            encryptedFram = Data()
            if fram.count >= 344 && (type == .libre2 || type == .libreUS14day) && UInt16(fram[0], fram[1]) != crc16(fram[2...23]) {
                encryptedFram = fram
                if let decryptedFRAM = try? Data(Libre2.decryptFRAM(type: type, id: uid, info: patchInfo, data: fram)) {
                    fram = decryptedFRAM
                }
            }
            updateCRCReport()
            guard !crcReport.contains("FAILED") else {
                state = .unknown
                return
            }

            if let sensorState = SensorState(rawValue: fram[4]) {
                state = sensorState
            }

            guard fram.count > 318 else { return }
            age = Int(fram[317]) << 8 + Int(fram[316])
            let startDate = lastReadingDate - Double(age) * 60
            reinitializations = Int(fram[318])

            guard fram.count > 327 else { return }
            // Int(fram[322]) << 8 + Int(fram[323]) correspond to patchInfo[2...3]
            region = Int(fram[323])
            maxLife = Int(fram[327]) << 8 + Int(fram[326])

            trend = []
            history = []
            let trendIndex = Int(fram[26])
            let historyIndex = Int(fram[27])

            for i in 0 ... 15 {
                var j = trendIndex - 1 - i
                if j < 0 { j += 16 }
                let raw = (Int(fram[29 + j * 6]) & 0x1F) << 8 + Int(fram[28 + j * 6])
                let temperature = (Int(fram[32 + j * 6]) & 0x3F) << 8 + Int(fram[31 + j * 6])
                var temperatureAdjustment = readBits(fram, 28 + j * 6, 0x26, 0x9) << 2
                let negativeAdjustment = readBits(fram, 28 + j * 6, 0x2f, 0x1)
                if negativeAdjustment != 0 { temperatureAdjustment = -temperatureAdjustment }
                let id = age - i
                let date = startDate + Double(age - i) * 60
                trend.append(Glucose(raw: raw, rawTemperature: temperature, temperatureAdjustment: temperatureAdjustment, id: id, date: date))
            }

            // FRAM is updated with a 3 minutes delay:
            // https://github.com/UPetersen/LibreMonitor/blob/Swift4/LibreMonitor/Model/SensorData.swift
            
            let preciseHistoryIndex = ((age - 3) / 15 ) % 32
            let delay = (age - 3) % 15 + 3
            var readingDate = lastReadingDate
            if preciseHistoryIndex == historyIndex {
                readingDate.addTimeInterval(60.0 * -Double(delay))
            } else {
                readingDate.addTimeInterval(60.0 * -Double(delay - 15))
            }

            for i in 0 ... 31 {
                var j = historyIndex - 1 - i
                if j < 0 { j += 32 }
                let raw = (Int(fram[125 + j * 6]) & 0x1F) << 8 + Int(fram[124 + j * 6])
                let temperature = (Int(fram[128 + j * 6]) & 0x3F) << 8 + Int(fram[127 + j * 6])
                var temperatureAdjustment = readBits(fram, 124 + j * 6, 0x26, 0x9) << 2
                let negativeAdjustment = readBits(fram, 124 + j * 6, 0x2f, 0x1)
                if negativeAdjustment != 0 { temperatureAdjustment = -temperatureAdjustment }
                let id = age - delay - i * 15
                let date = readingDate - Double(i) * 15 * 60
                history.append(Glucose(raw: raw, rawTemperature: temperature, temperatureAdjustment: temperatureAdjustment, id: id, date: date))}
        }
    }

    // Libre 2 and BLE streaming parameters
    var encryptedFram: Data = Data()
    var unlockCode: UInt32 = 42
    @Published var unlockCount: UInt16 = 0


    init() {
    }

    init(transmitter: Transmitter) {
        self.transmitter = transmitter
    }

    // For UI testing
    convenience init(state: SensorState, serial: String = "", age: Int = 0, uid: SensorUid = Data(), patchInfo: PatchInfo = Data()) {
        self.init()
        self.state = state
        self.serial = serial
        self.age = age
        self.uid = uid
        self.patchInfo = patchInfo
    }


    func updateCRCReport() {
        if fram.count != 344 {
            crcReport = "No FRAM read: can't verify CRC"

        } else {
            let headerCRC = fram[0...1].hex
            let bodyCRC   = fram[24...25].hex
            let footerCRC = fram[320...321].hex
            let computedHeaderCRC = String(format: "%04x", crc16(fram[2...23]))
            let computedBodyCRC   = String(format: "%04x", crc16(fram[26...319]))
            let computedFooterCRC = String(format: "%04x", crc16(fram[322...343]))

            var report = "Sensor header CRC16: \(headerCRC), computed: \(computedHeaderCRC) -> \(headerCRC == computedHeaderCRC ? "OK" : "FAILED")"
            report += "\nSensor body CRC16: \(bodyCRC), computed: \(computedBodyCRC) -> \(bodyCRC == computedBodyCRC ? "OK" : "FAILED")"
            report += "\nSensor footer CRC16: \(footerCRC), computed: \(computedFooterCRC) -> \(footerCRC == computedFooterCRC ? "OK" : "FAILED")"

            crcReport = report
        }
    }


    var calibrationInfo: CalibrationInfo {
       let i1 = readBits(fram, 2, 0, 3)
       let i2 = readBits(fram, 2, 3, 0xa)
       let i3 = readBits(fram, 0x150, 0, 8)
       let i4 = readBits(fram, 0x150, 8, 0xe)
       let negativei3 = readBits(fram, 0x150, 0x21, 1) != 0
       let i5 = readBits(fram, 0x150, 0x28, 0xc) << 2
       let i6 = readBits(fram, 0x150, 0x34, 0xc) << 2

       return CalibrationInfo(i1: i1, i2: i2, i3: negativei3 ? -i3 : i3, i4: i4, i5: i5, i6: i6)
     }

}


// https://github.com/UPetersen/LibreMonitor/blob/Swift4/LibreMonitor/Model/SensorSerialNumber.swift

func serialNumber(uid: SensorUid) -> String {
    let lookupTable = ["0","1","2","3","4","5","6","7","8","9","A","C","D","E","F","G","H","J","K","L","M","N","P","Q","R","T","U","V","W","X","Y","Z"]
    guard uid.count == 8 else { return "invalid uid" }
    let bytes = Array(uid.reversed().suffix(6))
    var fiveBitsArray = [UInt8]()
    fiveBitsArray.append( bytes[0] >> 3 )
    fiveBitsArray.append( bytes[0] << 2 + bytes[1] >> 6 )
    fiveBitsArray.append( bytes[1] >> 1 )
    fiveBitsArray.append( bytes[1] << 4 + bytes[2] >> 4 )
    fiveBitsArray.append( bytes[2] << 1 + bytes[3] >> 7 )
    fiveBitsArray.append( bytes[3] >> 2 )
    fiveBitsArray.append( bytes[3] << 3 + bytes[4] >> 5 )
    fiveBitsArray.append( bytes[4] )
    fiveBitsArray.append( bytes[5] >> 3 )
    fiveBitsArray.append( bytes[5] << 2 )
    return fiveBitsArray.reduce("0", {
        $0 + lookupTable[ Int(0x1F & $1) ]
    })
}


// https://github.com/UPetersen/LibreMonitor/blob/Swift4/LibreMonitor/Model/CRC.swift

func crc16(_ data: Data) -> UInt16 {
    let crc16table: [UInt16] = [0, 4489, 8978, 12955, 17956, 22445, 25910, 29887, 35912, 40385, 44890, 48851, 51820, 56293, 59774, 63735, 4225, 264, 13203, 8730, 22181, 18220, 30135, 25662, 40137, 36160, 49115, 44626, 56045, 52068, 63999, 59510, 8450, 12427, 528, 5017, 26406, 30383, 17460, 21949, 44362, 48323, 36440, 40913, 60270, 64231, 51324, 55797, 12675, 8202, 4753, 792, 30631, 26158, 21685, 17724, 48587, 44098, 40665, 36688, 64495, 60006, 55549, 51572, 16900, 21389, 24854, 28831, 1056, 5545, 10034, 14011, 52812, 57285, 60766, 64727, 34920, 39393, 43898, 47859, 21125, 17164, 29079, 24606, 5281, 1320, 14259, 9786, 57037, 53060, 64991, 60502, 39145, 35168, 48123, 43634, 25350, 29327, 16404, 20893, 9506, 13483, 1584, 6073, 61262, 65223, 52316, 56789, 43370, 47331, 35448, 39921, 29575, 25102, 20629, 16668, 13731, 9258, 5809, 1848, 65487, 60998, 56541, 52564, 47595, 43106, 39673, 35696, 33800, 38273, 42778, 46739, 49708, 54181, 57662, 61623, 2112, 6601, 11090, 15067, 20068, 24557, 28022, 31999, 38025, 34048, 47003, 42514, 53933, 49956, 61887, 57398, 6337, 2376, 15315, 10842, 24293, 20332, 32247, 27774, 42250, 46211, 34328, 38801, 58158, 62119, 49212, 53685, 10562, 14539, 2640, 7129, 28518, 32495, 19572, 24061, 46475, 41986, 38553, 34576, 62383, 57894, 53437, 49460, 14787, 10314, 6865, 2904, 32743, 28270, 23797, 19836, 50700, 55173, 58654, 62615, 32808, 37281, 41786, 45747, 19012, 23501, 26966, 30943, 3168, 7657, 12146, 16123, 54925, 50948, 62879, 58390, 37033, 33056, 46011, 41522, 23237, 19276, 31191, 26718, 7393, 3432, 16371, 11898, 59150, 63111, 50204, 54677, 41258, 45219, 33336, 37809, 27462, 31439, 18516, 23005, 11618, 15595, 3696, 8185, 63375, 58886, 54429, 50452, 45483, 40994, 37561, 33584, 31687, 27214, 22741, 18780, 15843, 11370, 7921, 3960]
    var crc = data.reduce(UInt16(0xFFFF)) { ($0 >> 8) ^ crc16table[Int(($0 ^ UInt16($1)) & 0xFF)] }
    var reverseCrc = UInt16(0)
    for _ in 0 ..< 16 {
        reverseCrc = reverseCrc << 1 | crc & 1
        crc >>= 1
    }
    return reverseCrc.byteSwapped
}


func checksummedFRAM(_ data: Data) -> Data {
    var fram = data

    let headerCRC = crc16(fram[         2 ..<  3 * 8])
    let bodyCRC =   crc16(fram[ 3 * 8 + 2 ..< 40 * 8])
    let footerCRC = crc16(fram[40 * 8 + 2 ..< 43 * 8])

    fram[ 0] =         UInt8(headerCRC >> 8)
    fram[ 1] =         UInt8(headerCRC & 0x00FF)
    fram[ 3 * 8] =     UInt8(bodyCRC >> 8)
    fram[ 3 * 8 + 1] = UInt8(bodyCRC & 0x00FF)
    fram[40 * 8] =     UInt8(footerCRC >> 8)
    fram[40 * 8 + 1] = UInt8(footerCRC & 0x00FF)

    if fram.count >= 244 * 8 {
        let commandsCRC = crc16(fram[43 * 8 + 2 ..< (244 - 6) * 8])    // Libre 1: 0x9e42
        fram[43 * 8] =     UInt8(commandsCRC >> 8)
        fram[43 * 8 + 1] = UInt8(commandsCRC & 0x00FF)
    }
    return fram
}


// https://github.com/ivalkou/LibreTools/blob/master/Sources/LibreTools/Sensor/Libre2.swift

enum Libre2 {
    /// Decrypts 43 blocks of Libre 2 FRAM
    /// - Parameters:
    ///   - type: Suppurted sensor type (.libre2, .libreUS14day)
    ///   - id: ID/Serial of the sensor. Could be retrieved from NFC as uid.
    ///   - info: Sensor info. Retrieved by sending command '0xa1' via NFC.
    ///   - data: Encrypted FRAM data
    /// - Returns: Decrypted FRAM data
    static func decryptFRAM(type: SensorType, id: SensorUid, info: PatchInfo, data: Data) throws -> [UInt8] {
        guard type == .libre2 || type == .libreUS14day else {
            struct DecryptFRAMError: LocalizedError {
                var errorDescription: String? { "Unsupported sensor type" }
            }
            throw DecryptFRAMError()
        }

        func getArg(block: Int) -> UInt16 {
            switch type {
            case .libreUS14day:
                if block < 3 || block >= 40 {
                    // For header and footer it is a fixed value.
                    return 0xcadc
                }
                return UInt16(info[5], info[4])
            case .libre2:
                return UInt16(info[5], info[4]) ^ 0x44
            default: fatalError("Unsupported sensor type")
            }
        }

        var result = [UInt8]()

        for i in 0 ..< 43 {
            let input = prepareVariables(id: id, x: UInt16(i), y: getArg(block: i))
            let blockKey = processCrypto(input: input)

            result.append(data[i * 8 + 0] ^ UInt8(truncatingIfNeeded: blockKey[0]))
            result.append(data[i * 8 + 1] ^ UInt8(truncatingIfNeeded: blockKey[0] >> 8))
            result.append(data[i * 8 + 2] ^ UInt8(truncatingIfNeeded: blockKey[1]))
            result.append(data[i * 8 + 3] ^ UInt8(truncatingIfNeeded: blockKey[1] >> 8))
            result.append(data[i * 8 + 4] ^ UInt8(truncatingIfNeeded: blockKey[2]))
            result.append(data[i * 8 + 5] ^ UInt8(truncatingIfNeeded: blockKey[2] >> 8))
            result.append(data[i * 8 + 6] ^ UInt8(truncatingIfNeeded: blockKey[3]))
            result.append(data[i * 8 + 7] ^ UInt8(truncatingIfNeeded: blockKey[3] >> 8))
        }
        return result
    }

    /// Decrypts Libre 2 BLE payload
    /// - Parameters:
    ///   - id: ID/Serial of the sensor. Could be retrieved from NFC as uid.
    ///   - data: Encrypted BLE data
    /// - Returns: Decrypted BLE data
    static func decryptBLE(id: SensorUid, data: Data) throws -> [UInt8] {
        let d = usefulFunction(id: id, x: UInt16(Sensor.Subcommand.activate.rawValue), y: 0x1b6a)
        let x = UInt16(d[1], d[0]) ^ UInt16(d[3], d[2]) | 0x63
        let y = UInt16(data[1], data[0]) ^ 0x63

        var key = [UInt8]()
        var initialKey = processCrypto(input: prepareVariables(id: id, x: x, y: y))

        for _ in 0 ..< 8 {
            key.append(UInt8(truncatingIfNeeded: initialKey[0]))
            key.append(UInt8(truncatingIfNeeded: initialKey[0] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[1]))
            key.append(UInt8(truncatingIfNeeded: initialKey[1] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[2]))
            key.append(UInt8(truncatingIfNeeded: initialKey[2] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[3]))
            key.append(UInt8(truncatingIfNeeded: initialKey[3] >> 8))
            initialKey = processCrypto(input: initialKey)
        }

        let result = data[2...].enumerated().map { i, value in
            value ^ key[i]
        }

        guard crc16(Data(result.prefix(42))) == UInt16(result[42], result[43]) else {
            struct DecryptBLEError: LocalizedError {
                var errorDescription: String? { "BLE data decryption failed" }
            }
            throw DecryptBLEError()
        }

        return result
    }

}

extension Libre2 {
    static let key: [UInt16] = [0xA0C5, 0x6860, 0x0000, 0x14C6]

    static func processCrypto(input: [UInt16]) -> [UInt16] {
        func op(_ value: UInt16) -> UInt16 {
            // We check for last 2 bits and do the xor with specific value if bit is 1
            var res = value >> 2 // Result does not include these last 2 bits

            if value & 1 != 0 { // If last bit is 1
                res = res ^ key[1]
            }

            if value & 2 != 0 { // If second last bit is 1
                res = res ^ key[0]
            }

            return res
        }

        let r0 = op(input[0]) ^ input[3]
        let r1 = op(r0) ^ input[2]
        let r2 = op(r1) ^ input[1]
        let r3 = op(r2) ^ input[0]
        let r4 = op(r3)
        let r5 = op(r4 ^ r0)
        let r6 = op(r5 ^ r1)
        let r7 = op(r6 ^ r2)

        let f1 = r0 ^ r4
        let f2 = r1 ^ r5
        let f3 = r2 ^ r6
        let f4 = r3 ^ r7

        return [f4, f3, f2, f1];
    }

    static func prepareVariables(id: SensorUid, x: UInt16, y: UInt16) -> [UInt16] {
        let s1 = UInt16(truncatingIfNeeded: UInt(UInt16(id[5], id[4])) + UInt(x) + UInt(y))
        let s2 = UInt16(truncatingIfNeeded: UInt(UInt16(id[3], id[2])) + UInt(key[2]))
        let s3 = UInt16(truncatingIfNeeded: UInt(UInt16(id[1], id[0])) + UInt(x) * 2)
        let s4 = 0x241a ^ key[3]

        return [s1, s2, s3, s4]
    }

    static func prepareVariables2(id: SensorUid, i1: UInt16, i2: UInt16, i3: UInt16, i4: UInt16) -> [UInt16] {
        let s1 = UInt16(truncatingIfNeeded: UInt(UInt16(id[5], id[4])) + UInt(i1))
        let s2 = UInt16(truncatingIfNeeded: UInt(UInt16(id[3], id[2])) + UInt(i2))
        let s3 = UInt16(truncatingIfNeeded: UInt(UInt16(id[1], id[0])) + UInt(i3) + UInt(key[2]))
        let s4 = UInt16(truncatingIfNeeded: UInt(i4) + UInt(key[3]))

        return [s1, s2, s3, s4]
    }

    static func usefulFunction(id: SensorUid, x: UInt16, y: UInt16) -> [UInt8] {
        let blockKey = processCrypto(input: prepareVariables(id: id, x: x, y: y))
        let low = blockKey[0]
        let high = blockKey[1]

        // https://github.com/ivalkou/LibreTools/issues/2: "XOR with inverted low/high words in usefulFunction()"
        let r1 = low ^ 0x4163
        let r2 = high ^ 0x4344

        return [
            UInt8(truncatingIfNeeded: r1),
            UInt8(truncatingIfNeeded: r1 >> 8),
            UInt8(truncatingIfNeeded: r2),
            UInt8(truncatingIfNeeded: r2 >> 8)
        ]
    }

    static func streamingUnlockPayload(id: SensorUid, info: PatchInfo, enableTime: UInt32, unlockCount: UInt16) -> [UInt8] {

        // First 4 bytes are just int32 of timestamp + unlockCount
        let time = enableTime + UInt32(unlockCount)
        let b: [UInt8] = [
            UInt8(time & 0xFF),
            UInt8((time >> 8) & 0xFF),
            UInt8((time >> 16) & 0xFF),
            UInt8((time >> 24) & 0xFF)
        ]

        // Then we need data of activation command and enable command that were sent to sensor
        let ad = usefulFunction(id: id, x: UInt16(Sensor.Subcommand.activate.rawValue), y: 0x1b6a)
        let ed = usefulFunction(id: id, x: UInt16(Sensor.Subcommand.enableStreaming.rawValue), y: UInt16(enableTime & 0xFFFF) ^ UInt16(info[5], info[4]))

        let t11 = UInt16(ed[1], ed[0]) ^ UInt16(b[3], b[2])
        let t12 = UInt16(ad[1], ad[0])
        let t13 = UInt16(ed[3], ed[2]) ^ UInt16(b[1], b[0])
        let t14 = UInt16(ad[3], ad[2])

        let t2 = processCrypto(input: prepareVariables2(id: id, i1: t11, i2: t12, i3: t13, i4: t14))

        // TODO extract if secret
        let t31 = crc16(Data([0xc1, 0xc4, 0xc3, 0xc0, 0xd4, 0xe1, 0xe7, 0xba, UInt8(t2[0] & 0xFF), UInt8((t2[0] >> 8) & 0xFF)])).byteSwapped
        let t32 = crc16(Data([UInt8(t2[1] & 0xFF), UInt8((t2[1] >> 8) & 0xFF),
                              UInt8(t2[2] & 0xFF), UInt8((t2[2] >> 8) & 0xFF),
                              UInt8(t2[3] & 0xFF), UInt8((t2[3] >> 8) & 0xFF)])).byteSwapped
        let t33 = crc16(Data([ad[0], ad[1], ad[2], ad[3], ed[0], ed[1]])).byteSwapped
        let t34 = crc16(Data([ed[2], ed[3], b[0], b[1], b[2], b[3]])).byteSwapped

        let t4 = processCrypto(input: prepareVariables2(id: id, i1: t31, i2: t32, i3: t33, i4: t34))

        let res = [
            UInt8(t4[0] & 0xFF),
            UInt8((t4[0] >> 8) & 0xFF),
            UInt8(t4[1] & 0xFF),
            UInt8((t4[1] >> 8) & 0xFF),
            UInt8(t4[2] & 0xFF),
            UInt8((t4[2] >> 8) & 0xFF),
            UInt8(t4[3] & 0xFF),
            UInt8((t4[3] >> 8) & 0xFF)
        ]

        return [b[0], b[1], b[2], b[3], res[0], res[1], res[2], res[3], res[4], res[5], res[6], res[7]]
    }

}


// https://github.com/dabear/SwitftLibreOOPWebPublic/blob/master/SwiftLibreOOPWeb/Model/SensorData.swift

func readBits(_ buffer: Data, _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int) -> Int {
    guard bitCount != 0 else {
        return 0
    }
    var res = 0
    for i in 0 ..< bitCount {
        let totalBitOffset = byteOffset * 8 + bitOffset + i
        let byte = Int(floor(Float(totalBitOffset) / 8))
        let bit = totalBitOffset % 8
        if totalBitOffset >= 0 && ((buffer[byte] >> bit) & 0x1) == 1 {
            res |= 1 << i
        }
    }
    return res
}

func writeBits(_ buffer: Data, _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int, _ value: Int) -> Data {
    var res = buffer
    for i in 0 ..< bitCount {
        let totalBitOffset = byteOffset * 8 + bitOffset + i
        let byte = Int(floor(Double(totalBitOffset) / 8))
        let bit = totalBitOffset % 8
        let bitValue = (value >> i) & 0x1
        res[byte] = (res[byte] & ~(1 << bit) | (UInt8(bitValue) << bit))
    }
    return res
}
