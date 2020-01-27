import Foundation

// https://github.com/bubbledevteam/xdripswift/commit/07135da


struct OOPServer {
    var siteURL: String
    var token: String
    var calibrationEndpoint: String
    var historyEndpoint: String

    static let `default`: OOPServer = OOPServer(siteURL: "https://www.glucose.space/",
                                                token: "bubble-201907",
                                                calibrationEndpoint: "calibrateSensor",
                                                historyEndpoint: "libreoop2")
}


struct HistoricGlucose: Codable {
    let dataQuality: Int
    let id: Int
    let value: Int
}

struct OOPHistoryData: Codable {
    var alarm: String
    var esaMinutesToWait: Int
    var historicGlucose: [HistoricGlucose]
    var isActionable: Bool
    var lsaDetected: Bool
    var realTimeGlucose: HistoricGlucose
    var trendArrow: String

    func glucoseData(sensorAge: Int, readingDate: Date) -> [Glucose] {
        // let current = Glucose(raw: realTimeGlucose.value * 10, id: realTimeGlucose.id, date: readingDate)
        var array = [Glucose]()
        let startDate = readingDate - Double(sensorAge) * 60
        var history = historicGlucose
        if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
            history = history.reversed()
        }
        for g in history {
            let glucose = Glucose(g.value, id: g.id, date: startDate + Double(g.id * 60))
            array.append(glucose)
        }
        return array
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


func postToLibreOOP(server: OOPServer, bytes: Data = Data(), date: Date = Date(), patchUid: Data? = nil, patchInfo: Data? = nil, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
    let site = server.siteURL + (patchInfo == nil ? server.calibrationEndpoint : server.historyEndpoint)
    let date = Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    var parameters = ["content": "\(bytes.hex)"]
    if let patchInfo = patchInfo {
        parameters["accesstoken"] = server.token
        parameters["patchUid"] = patchUid!.hex
        parameters["patchInfo"] = patchInfo.hex
    } else {
        parameters["token"] = server.token
        parameters["timestamp"] = "\(date)"
    }
    let request = NSMutableURLRequest(url: URL(string: site)!)
    request.httpMethod = "POST"
    request.httpBody = parameters.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }.joined(separator: "&").data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    URLSession.shared.dataTask(with: request as URLRequest) {
        data, response, error in
        DispatchQueue.main.async {
            completion(data, response, error)
        }
    }.resume()
}


// FALLING_QUICKLY | FALLING | STABLE | RISING | RISING_QUICKLY | NOT_DETERMINED

public func trendSymbol(for oopAlarm: String) -> String {
    switch oopAlarm {
    case "RISING_QUICKLY":  return "↑"
    case "RISING":          return "↗︎"
    case "STABLE":          return "→"
    case "FALLING":         return "↘︎"
    case "FALLING_QUICKLY": return "↓"
    default: return "---"
    }
}
