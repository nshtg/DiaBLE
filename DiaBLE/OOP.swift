import Foundation

// https://github.com/bubbledevteam/bubble-client-swift/blob/master/LibreSensor/


struct OOPServer {
    var siteURL: String
    var token: String
    var calibrationEndpoint: String
    var historyEndpoint: String

    static let `default`: OOPServer = OOPServer(siteURL: "https://www.glucose.space",
                                                token: "bubble-201907",
                                                calibrationEndpoint: "calibrateSensor",
                                                historyEndpoint: "libreoop2")
}


protocol GlucoseSpaceResponse {
    var isError: Bool { get }
    var sensorTime: Int? { get }
    var canGetParameters: Bool { get }
    var sensorState: SensorState { get }
    var valueError: Bool { get }
    func glucoseData(date: Date) ->(Glucose?, [Glucose])
}


struct OOPHistoryValue: Codable {
    let bg: Double?
    let quality: Int?
    let time: Int?
}

struct GlucoseSpaceHistoricGlucose: Codable {
    let value: Int
    let dataQuality: Int
    let id: Int
}


struct GlucoseSpaceHistoryResponse: Codable {
    var alarm: String
    var esaMinutesToWait: Int
    var historicGlucose: [GlucoseSpaceHistoricGlucose]
    var isActionable: Bool
    var lsaDetected: Bool
    var realTimeGlucose: GlucoseSpaceHistoricGlucose
    var trendArrow: String
    var msg: String?
    var errcode: String?
    var endTime: Int?

    /// msg
    enum Error: String {
        case RESULT_SENSOR_STORAGE_STATE
        case RESCAN_SENSOR_BAD_CRC
        case TERMINATE_SENSOR_NORMAL_TERMINATED_STATE
        case TERMINATE_SENSOR_ERROR_TERMINATED_STATE
        case TERMINATE_SENSOR_CORRUPT_PAYLOAD
        case FATAL_ERROR_BAD_ARGUMENTS
        case TYPE_SENSOR_NOT_STARTED
        case TYPE_SENSOR_STARTING
        case TYPE_SENSOR_Expired
        case TYPE_SENSOR_END
        case TYPE_SENSOR_ERROR
        case TYPE_SENSOR_OK
        case TYPE_SENSOR_DETERMINED
    }

    func glucoseData(sensorAge: Int, readingDate: Date) -> [Glucose] {
        var array = [Glucose]()
        var sensorAge = sensorAge
        if sensorAge == 0 { // encrpyted FRAM of the Libre 2
            sensorAge = realTimeGlucose.id // FIXME: can differ 1 minute from the real age
        }
        let startDate = readingDate - Double(sensorAge) * 60
        // let current = Glucose(realTimeGlucose.value, id: realTimeGlucose.id, date: startDate + Double(realTimeGlucose.id * 60))
        var history = historicGlucose
        if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
            history = history.reversed()
        }
        for g in history {
            let glucose = Glucose(g.value, id: g.id, date: startDate + Double(g.id * 60), source: "OOP" )
            array.append(glucose)
        }
        return array
    }
}


struct GlucoseSpaceA2HistoryResponse: Codable { // TODO: implement the GlucoseSpaceResponse protocol
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


// TODO: use Combine Result

func postToOOP(server: OOPServer, bytes: Data = Data(), date: Date = Date(), patchUid: Data? = nil, patchInfo: Data? = nil, handler: @escaping (Data?, URLResponse?, Error?, [URLQueryItem]) -> Void) {
    var urlComponents = URLComponents(string: server.siteURL + "/" + (patchInfo == nil ? server.calibrationEndpoint : server.historyEndpoint))!
    var queryItems = [URLQueryItem(name: "content", value: bytes.hex)]
    let date = Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    if let patchInfo = patchInfo {
        queryItems.append(contentsOf: [
            URLQueryItem(name: "accesstoken", value: server.token),
            URLQueryItem(name: "patchUid", value: patchUid!.hex),
            URLQueryItem(name: "patchInfo", value: patchInfo.hex)
        ])
    } else {
        queryItems.append(contentsOf: [
            URLQueryItem(name: "token", value: server.token),
            URLQueryItem(name: "timestamp", value: "\(date)")
        ])
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
    static func trendSymbol(for trend: String) -> String {
        switch trend {
        case "RISING_QUICKLY":  return "↑"
        case "RISING":          return "↗︎"
        case "STABLE":          return "→"
        case "FALLING":         return "↘︎"
        case "FALLING_QUICKLY": return "↓"
        default:                return "---" // NOT_DETERMINED
        }
    }
    static func alarmDescription(for alarm: String) -> String {
        switch alarm {
        case "PROJECTED_HIGH_GLUCOSE": return "GOING HIGH"
        case "HIGH_GLUCOSE":           return "HIGH"
        case "GLUCOSE_OK":             return "OK"
        case "LOW_GLUCOSE":            return "LOW"
        case "PROJECTED_LOW_GLUCOSE":  return "GOING LOW"
        default:                       return "" // NOT_DETERMINED
        }
    }
}
