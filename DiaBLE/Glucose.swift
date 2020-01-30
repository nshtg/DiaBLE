import Foundation


enum GlucoseUnit: String, CustomStringConvertible, CaseIterable {
    case mgdl, mmoll

    var description: String {
        switch self {
        case .mgdl:  return "mg/dl"
        case .mmoll: return "mmol/L"
        }
    }
}


/// id: minutes from sensor start
struct Glucose: Identifiable {
    let id: Int
    let date: Date
    let raw: Int
    let temperature: Int
    var value: Int = 0
    var calibration: Calibration? {
        willSet(newCalibration) {
            let slope  = newCalibration!.slope + newCalibration!.slopeSlope  * Double(temperature) + newCalibration!.offsetSlope  + newCalibration!.slopeExtra
            let offset = newCalibration!.offset + newCalibration!.slopeOffset * Double(temperature) + newCalibration!.offsetOffset + newCalibration!.offsetExtra
            value = Int(round(offset + slope * Double(raw)))
        }
    }
    var source: String = ""

    init(raw: Int, temperature: Int = 0, calibration: Calibration? = nil, id: Int = 0, date: Date = Date()) {
        self.id = id
        self.date = date
        self.raw = raw
        self.value = raw / 10
        self.temperature = temperature
        self.calibration = calibration
    }

    init(bytes: [UInt8], calibration: Calibration? = nil, id: Int = 0, date: Date = Date()) {
        let raw = (Int(bytes[1] & 0x1F) << 8) + Int(bytes[0])
        let temperature = (Int(bytes[4] & 0x3F) << 8)  + Int(bytes[3])
        self.init(raw: raw, temperature: temperature, calibration: calibration, id: id, date: date)
    }

    init(_ value: Int, id: Int = 0, date: Date = Date(), source: String = "") {
        self.init(raw: value * 10, id: id, date: date)
        self.source = source
    }
}


struct Calibration: Codable {
    var slope: Double = 0.0
    var offset: Double = 0.0
    var slopeSlope: Double = 0.0
    var slopeOffset: Double = 0.0
    var offsetOffset: Double = 0.0
    var offsetSlope: Double = 0.0
    var slopeExtra: Double = 0.0
    var offsetExtra: Double = 0.0

    enum CodingKeys: String, CodingKey,  CustomStringConvertible {
        case slopeSlope   = "slope_slope"
        case slopeOffset  = "slope_offset"
        case offsetOffset = "offset_offset"
        case offsetSlope  = "offset_slope"

        var description: String {
            switch self {
            case .slopeSlope:   return "Slope slope"
            case .slopeOffset:  return "Offset slope"
            case .offsetOffset: return "Offset offset"
            case .offsetSlope:  return "Slope offset"
            }
        }
    }
}


// https://github.com/gshaviv/ninety-two/blob/master/WoofWoof/TrendSymbol.swift

public func trendSymbol(for trend: Double) -> String {
    if trend > 2.0 {
        return "⇈"
    } else if trend > 1.0 {
        return "↑"
    } else if trend > 0.33 {
        return "↗︎"
    } else if trend > -0.33 {
        return "→"
    } else if trend > -1.0 {
        return "↘︎"
    } else if trend > -2.0 {
        return "↓"
    } else {
        return "⇊"
    }
}
