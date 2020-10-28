import Foundation

// https://github.com/bubbledevteam/bubble-client-swift/blob/master/LibreSensor/


struct OOPServer {
    var siteURL: String
    var token: String
    var calibrationEndpoint: String
    var historyEndpoint: String
    var activationEndpoint: String

    static let `default`: OOPServer = OOPServer(siteURL: "https://www.glucose.space",
                                                token: "bubble-201907",
                                                calibrationEndpoint: "calibrateSensor",
                                                historyEndpoint: "libreoop2",
                                                activationEndpoint: "activation")
}

// TODO: new "callnox" endpoint replies with a GlucoseSpaceA2HistoryResponse specific for an 0xA2 Libre 1 patch


// TODO: Codable
class OOPHistoryResponse {
    var currentGlucose: Int = 0
    var historyValues: [Glucose] = []
}

protocol GlucoseSpaceHistory {
    var isError: Bool { get }
    var sensorTime: Int? { get }
    var canGetParameters: Bool { get }
    var sensorState: SensorState { get }
    var valueError: Bool { get }
    func glucoseData(date: Date) ->(Glucose?, [Glucose])
}


enum OOPDataQuality: Int, CustomStringConvertible {
    case OK                      = 0
    case SD14_FIFO_OVERFLOW      = 1
    case FILTER_DELTA            = 2
    case WORK_VOLTAGE            = 4
    case PEAK_DELTA_EXCEEDED     = 8
    case AVG_DELTA_EXCEEDED      = 16     //   0x10
    case RF                      = 32     //   0x20
    case REF_R                   = 64     //   0x40
    case SIGNAL_SATURATED        = 128    //   0x80
    case SENSOR_SIGNAL_LOW       = 256    //  0x100
    case THERMISTOR_OUT_OF_RANGE = 2048   //  0x800
    case TEMP_HIGH               = 8192   // 0x2000
    case TEMP_LOW                = 16384  // 0x4000
    case INVALID_DATA            = 32768  // 0x8000

    var description: String {
        switch self {
        case .OK:                  return "OK"
        case .SD14_FIFO_OVERFLOW:  return "SD14_FIFO_OVERFLOW"
        case .FILTER_DELTA:        return "FILTER_DELTA"
        case .WORK_VOLTAGE:        return "WORK_VOLTAGE"
        case .PEAK_DELTA_EXCEEDED: return "PEAK_DELTA_EXCEEDED"
        case .AVG_DELTA_EXCEEDED:  return "AVG_DELTA_EXCEEDED"
        case .RF:                  return "RF"
        case .REF_R:               return "REF_R"
        case .SIGNAL_SATURATED:    return "SIGNAL_SATURATED"
        case .SENSOR_SIGNAL_LOW:   return "SENSOR_SIGNAL_LOW"
        case .THERMISTOR_OUT_OF_RANGE: return "THERMISTOR_OUT_OF_RANGE"
        case .TEMP_HIGH:           return "TEMP_HIGH"
        case .TEMP_LOW:            return "TEMP_LOW"
        case .INVALID_DATA:        return "INVALID_DATA"
        }
    }
}


struct OOPHistoryValue: Codable {
    let bg: Double
    let quality: Int
    let time: Int
}

struct GlucoseSpaceHistoricGlucose: Codable {
    let value: Int
    let dataQuality: Int    // if != 0, the value is erroneous
    let id: Int
}


class GlucoseSpaceHistoryResponse: OOPHistoryResponse, Codable { // TODO: implement the GlucoseSpaceHistory protocol
    var alarm: String?
    var esaMinutesToWait: Int?
    var historicGlucose: [GlucoseSpaceHistoricGlucose] = []
    var isActionable: Bool?
    var lsaDetected: Bool?
    var realTimeGlucose: GlucoseSpaceHistoricGlucose = GlucoseSpaceHistoricGlucose(value: 0, dataQuality: 0, id: 0)
    var trendArrow: String?
    var msg: String?
    var errcode: String?
    var endTime: Int?    // if != 0, the sensor expired

    enum Msg: String {
        case RESULT_SENSOR_STORAGE_STATE
        case RESCAN_SENSOR_BAD_CRC

        case TERMINATE_SENSOR_NORMAL_TERMINATED_STATE    // errcode: 10
        case TERMINATE_SENSOR_ERROR_TERMINATED_STATE
        case TERMINATE_SENSOR_CORRUPT_PAYLOAD

        // HTTP request bad arguments
        case FATAL_ERROR_BAD_ARGUMENTS

        // sensor state
        case TYPE_SENSOR_NOT_STARTED
        case TYPE_SENSOR_STARTING
        case TYPE_SENSOR_Expired
        case TYPE_SENSOR_END
        case TYPE_SENSOR_ERROR
        case TYPE_SENSOR_OK
        case TYPE_SENSOR_DETERMINED
    }


    func glucoseData(sensorAge: Int, readingDate: Date) -> [Glucose] {
        historyValues = [Glucose]()
        let startDate = readingDate - Double(sensorAge) * 60
        // let current = Glucose(realTimeGlucose.value, id: realTimeGlucose.id, date: startDate + Double(realTimeGlucose.id * 60))
        currentGlucose = realTimeGlucose.value
        var history = historicGlucose
        if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
            history = history.reversed()
        }
        for g in history {
            let glucose = Glucose(g.value, id: g.id, date: startDate + Double(g.id * 60), source: "OOP" )
            historyValues.append(glucose)
        }
        return historyValues
    }
}


class GlucoseSpaceA2HistoryResponse: OOPHistoryResponse, Codable  { // TODO: implement the GlucoseSpaceHistory protocol
    var errcode: Int?
    var list: [GlucoseSpaceList]?

    var content: OOPCurrentValue? {
        return list?.first?.content
    }
}

struct GlucoseSpaceList: Codable {
    let content: OOPCurrentValue?
    let timestamp: Int?
}

struct OOPCurrentValue: Codable {
    let currentTime: Int?
    let currentTrend: Int?
    let serialNumber: String?
    let historyValues: [OOPHistoryValue]?
    let currentBg: Double?
    let timestamp: Int?
    enum CodingKeys: String, CodingKey {
        case currentTime
        case currentTrend = "currenTrend"
        case serialNumber
        case historyValues = "historicBg"
        case currentBg
        case timestamp
    }
}


/// errcode: 4, msg: "content crc16 false"
/// errcode: 5, msg: "oop result error" with terminated sensors

struct OOPCalibrationResponse: Codable {
    let errcode: Int
    let parameters: Calibration
    enum CodingKeys: String, CodingKey {
        case errcode
        case parameters = "slope"
    }
}



// https://github.com/bubbledevteam/bubble-client-swift/blob/master/LibreSensor/LibreOOPResponse.swift

// TODO: when adding URLQueryItem(name: "appName", value: "diabox")
struct GetCalibrationStatusResult: Codable {
    var status: String?
    var slopeSlope: String?
    var slopeOffset: String?
    var offsetOffset: String?
    var offsetSlope: String?
    var uuid: String?
    var isValidForFooterWithReverseCRCs: Double?

    enum CodingKeys: String, CodingKey {
        case status
        case slopeSlope = "slope_slope"
        case slopeOffset = "slope_offset"
        case offsetOffset = "offset_offset"
        case offsetSlope = "offset_slope"
        case uuid
        case isValidForFooterWithReverseCRCs = "isValidForFooterWithReverseCRCs"
    }
}


struct GlucoseSpaceActivationResponse: Codable {
    let error: Int
    let productFamily: Int
    let activationCommand: Int
    let activationPayload: String
}


// TODO: use Combine Result

func postToOOP(server: OOPServer, bytes: Data = Data(), date: Date = Date(), patchUid: SensorUid? = nil, patchInfo: PatchInfo? = nil, handler: @escaping (Data?, URLResponse?, Error?, [URLQueryItem]) -> Void) {
    var urlComponents = URLComponents(string: server.siteURL + "/" + (patchInfo == nil ? server.calibrationEndpoint : (bytes.count > 0 ? server.historyEndpoint : server.activationEndpoint)))!
    var queryItems: [URLQueryItem] = bytes.count > 0 ? [URLQueryItem(name: "content", value: bytes.hex)] : []
    let date = Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    if let patchInfo = patchInfo {
        queryItems += [
            URLQueryItem(name: "accesstoken", value: server.token),
            URLQueryItem(name: "patchUid", value: patchUid!.hex),
            URLQueryItem(name: "patchInfo", value: patchInfo.hex)
        ]
    } else {
        queryItems += [
            URLQueryItem(name: "token", value: server.token),
            URLQueryItem(name: "timestamp", value: "\(date)")
            // , URLQueryItem(name: "appName", value: "diabox")
        ]
    }
    urlComponents.queryItems = queryItems
    if let url = urlComponents.url {
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            DispatchQueue.main.async {
                handler(data, response, error, queryItems)
            }
        }.resume()
    }
}


struct OOP {

    enum TrendArrow: String, CaseIterable {
        case NOT_DETERMINED
        case FALLING_QUICKLY
        case FALLING
        case STABLE
        case RISING
        case RISING_QUICKLY

        var symbol: String {
            switch self {
            case .FALLING_QUICKLY: return "↓"
            case .FALLING:         return "↘︎"
            case .STABLE:          return "→"
            case .RISING:          return "↗︎"
            case .RISING_QUICKLY:  return "↑"
            default:               return "---"
            }
        }
    }

    enum Alarm: String, CaseIterable {
        case NOT_DETERMINED
        case LOW_GLUCOSE
        case PROJECTED_LOW_GLUCOSE
        case GLUCOSE_OK
        case PROJECTED_HIGH_GLUCOSE
        case HIGH_GLUCOSE

        var description: String {
            switch self {
            case .LOW_GLUCOSE:            return "LOW"
            case .PROJECTED_LOW_GLUCOSE:  return "GOING LOW"
            case .GLUCOSE_OK:             return "OK"
            case .PROJECTED_HIGH_GLUCOSE: return "GOING HIGH"
            case .HIGH_GLUCOSE:           return "HIGH"
            default:                      return ""
            }
        }
    }

}
