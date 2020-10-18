import Foundation


enum GlucoseUnit: String, CustomStringConvertible, CaseIterable, Identifiable {
    case mgdl, mmoll
    var id: String { rawValue}

    var description: String {
        switch self {
        case .mgdl:  return "mg/dl"
        case .mmoll: return "mmol/L"
        }
    }
}


/// id: minutes from sensor start
struct Glucose: Identifiable, Codable {
    let id: Int
    let date: Date
    let raw: Int
    let rawTemperature: Int
    let temperatureAdjustment: Int
    var value: Int = 0
    var temperature: Double = 0
    var calibration: Calibration? {
        willSet(newCalibration) {
            let slope  = (newCalibration!.slope + newCalibration!.slopeSlope  * Double(rawTemperature) + newCalibration!.offsetSlope) * newCalibration!.extraSlope
            let offset = newCalibration!.offset + newCalibration!.slopeOffset * Double(rawTemperature) + newCalibration!.offsetOffset + newCalibration!.extraOffset
            value = Int(round(slope * Double(raw) + offset))
        }
    }
    var source: String = ""

    init(raw: Int, rawTemperature: Int = 0, temperatureAdjustment: Int = 0, calibration: Calibration? = nil, id: Int = 0, date: Date = Date()) {
        self.id = id
        self.date = date
        self.raw = raw
        self.value = raw / 10
        self.rawTemperature = rawTemperature
        self.temperatureAdjustment = temperatureAdjustment
        self.calibration = calibration
    }

    init(bytes: [UInt8], calibration: Calibration? = nil, id: Int = 0, date: Date = Date()) {
        let raw = (Int(bytes[1] & 0x1F) << 8) + Int(bytes[0])
        let rawTemperature = (Int(bytes[4] & 0x3F) << 8)  + Int(bytes[3])
        // TODO: temperatureAdjustment
        self.init(raw: raw, rawTemperature: rawTemperature, calibration: calibration, id: id, date: date)
    }

    init(_ value: Int, temperature: Double = 0, id: Int = 0, date: Date = Date(), source: String = "") {
        self.init(raw: value * 10, id: id, date: date)
        self.temperature = temperature
        self.source = source
    }
}


func factoryGlucose(raw: Glucose, calibrationInfo: CalibrationInfo) -> Glucose {
    let x: Double = 1000 + 71500
    let y: Double = 1000

    let ca = 0.0009180023
    let cb = 0.0001964561
    let cc = 0.0000007061775
    let cd = 0.00000005283566

    let R = ((Double(raw.rawTemperature) * x) / Double(raw.temperatureAdjustment + calibrationInfo.i6)) - y
    let logR = Darwin.log(R)
    let d = pow(logR, 3) * cd + pow(logR, 2) * cc + logR * cb + ca
    let temperature = 1 / d - 273.15

    let value = raw.raw * 10

    // TODO

    return Glucose(value, temperature: temperature)
}


struct Calibration: Codable, Equatable {
    var slope: Double = 0.0
    var offset: Double = 0.0
    var slopeSlope: Double = 0.0
    var slopeOffset: Double = 0.0
    var offsetOffset: Double = 0.0
    var offsetSlope: Double = 0.0
    var extraSlope: Double = 1.0
    var extraOffset: Double = 0.0

    enum CodingKeys: String, CodingKey, CustomStringConvertible {
        case slopeSlope   = "slope_slope"
        case slopeOffset  = "slope_offset"
        case offsetOffset = "offset_offset"
        case offsetSlope  = "offset_slope"

        // Pay attention to the inversions:
        // enums are intended to be read as "term + subfix", therefore .slopeOffset = "slope of the offset" => "Offset slope"
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
