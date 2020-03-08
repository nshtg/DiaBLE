import Foundation

enum SensorType: String, CustomStringConvertible {
    case libre1   = "Libre 1"
    case libre2   = "Libre 2"
    case libreUS  = "Libre US"
    case librePro = "Libre Pro"
    case unknown  = "Libre"

    var description: String { self.rawValue }

    var serialPrefix: String {
        switch self {
        case .librePro: return "1"
        case .libre2:   return "3"
        default:        return "0"
        }
    }
}

enum SensorState: UInt8, CustomStringConvertible {
    case notYetStarted = 0x01
    case starting
    case ready
    case expired
    case shutdown
    case failure
    case unknown

    var description: String {
        switch self {
        case .notYetStarted: return "Not started"
        case .starting:      return "Starting"
        case .ready:         return "Ready"
        case .expired:       return "Expired"
        case .shutdown:      return "Shut down"
        case .failure:       return "Failure"
        default:             return "Unknown"
        }
    }
}


class Sensor: ObservableObject {

    var type: SensorType = .unknown
    @Published var state: SensorState = SensorState.unknown
    var crcReport: String = ""
    @Published var lastReadingDate = Date()
    @Published var transmitter: Transmitter?

    @Published var age: Int = 0
    var serial: String = ""

    @Published var currentGlucose: Int = 0

    var patchInfo: Data = Data() {
        willSet(info) {
            type = sensorType(patchInfo: info)
            if serial != "" {
                serial = type.serialPrefix + serial.dropFirst()
            }
        }
    }

    var uid: Data = Data() {
        willSet(uid) {
            serial = serialNumber(uid: uid)
        }
    }

    var trend: [Glucose] = []
    var history: [Glucose] = []

    var fram: Data = Data() {
        didSet {

            updateCRCReport()
            guard !crcReport.contains("FAILED") else { return }

            if let sensorState = SensorState(rawValue: fram[4]) {
                state = sensorState
            }
            age = Int(fram[317]) << 8 + Int(fram[316])
            let startDate = lastReadingDate - Double(age) * 60

            trend = []
            history = []
            let trendIndex = Int(fram[26])
            let historyIndex = Int(fram[27])

            for i in 0 ... 15 {
                var j = trendIndex - 1 - i
                if j < 0 { j += 16 }
                let raw = (Int(fram[29 + j * 6]) & 0x1F) << 8 + Int(fram[28 + j * 6])
                let temperature = (Int(fram[32 + j * 6]) & 0x3F) << 8 + Int(fram[31 + j * 6])
                trend.append(Glucose(raw: raw, temperature: temperature, id: age - i, date: startDate + Double(age - i) * 60))
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
                history.append(Glucose(raw: raw, temperature: temperature, id: age - delay - i * 15, date: readingDate - Double(i) * 15 * 60))
            }
        }
    }


    init() {
    }

    init(transmitter: Transmitter) {
        self.transmitter = transmitter
    }

    // For UI testing
    convenience init(state: SensorState, serial: String = "", age: Int = 0) {
        self.init()
        self.state = state
        self.serial = serial
        self.age = age
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
}


// https://github.com/keencave/LBridge/blob/master/LBridge_Arduino_V11/LBridge_Arduino_V1.1.02_190502_2120/LBridge_Arduino_V1.1.02_190502_2120.ino

func sensorType(patchInfo: Data) -> SensorType {

    var type: SensorType

    // Germany is DF 00 00 01, Canada is DF 00 00 04
    if patchInfo[0] == 0xDF && patchInfo[1] == 0x00 && patchInfo[2] == 0x00 { //   && patchInfo[3] == 0x01
        type = .libre1
    } else if patchInfo[0] == 0x9D && patchInfo[1] == 0x08 && patchInfo[2] == 0x30 && patchInfo[3] == 0x01 {
        type = .libre2
    } else if patchInfo[0] == 0xE5 && patchInfo[1] == 0x00 && patchInfo[2] == 0x03 && patchInfo[3] == 0x02 {
        type = .libreUS
    } else if patchInfo[0] == 0x70 && patchInfo[1] == 0x00 && patchInfo[2] == 0x10 && patchInfo[3] == 0x00 {
        type = .librePro
    } else {
        type = .unknown
    }

    return type
}


// https://github.com/UPetersen/LibreMonitor/blob/Swift4/LibreMonitor/Model/SensorSerialNumber.swift

func serialNumber(uid: Data) -> String {
    let lookupTable = ["0","1","2","3","4","5","6","7","8","9","A","C","D","E","F","G","H","J","K","L","M","N","P","Q","R","T","U","V","W","X","Y","Z"]
    guard uid.count == 8 else {return "invalid uid"}
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
