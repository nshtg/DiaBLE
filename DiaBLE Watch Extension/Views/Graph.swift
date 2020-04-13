import Foundation
import SwiftUI


struct Graph: View {
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings


    func yMax() -> Double {
        Double([
            self.history.rawValues.map{$0.value}.max() ?? 0,
            self.history.values.map{$0.value}.max() ?? 0,
            self.history.calibratedValues.map{$0.value}.max() ?? 0,
            Int(self.settings.targetHigh + 20)
            ].max()!)
    }


    var body: some View {
        ZStack {

            // Glucose range rect in the background
            GeometryReader { geometry in
                Path() { path in
                    let width  = Double(geometry.size.width) - 60.0
                    let height = Double(geometry.size.height)
                    let yScale = (height - 20.0) / self.yMax()
                    path.addRect(CGRect(x: 1.0 + 30.0, y: height - self.settings.targetHigh * yScale + 1.0, width: width - 2.0, height: (self.settings.targetHigh - self.settings.targetLow) * yScale - 1.0))
                }.fill(Color.green).opacity(0.15)
            }

            // Target glucose low and high labels at the right
            GeometryReader { geometry in
                ZStack {
                    Text("\(Int(self.settings.targetHigh))")
                        .position(x: CGFloat(Double(geometry.size.width) - 15.0), y: CGFloat(Double(geometry.size.height) - (Double(geometry.size.height) - 20.0) / self.yMax() * self.settings.targetHigh))
                    Text("\(Int(self.settings.targetLow))")
                        .position(x: CGFloat(Double(geometry.size.width) - 15.0), y: CGFloat(Double(geometry.size.height) - (Double(geometry.size.height) - 20.0) / self.yMax() * self.settings.targetLow))
                }.font(.footnote).foregroundColor(.gray)
            }

            // History raw values
            GeometryReader { geometry in
                Path() { path in
                    let width  = Double(geometry.size.width) - 60.0
                    let height = Double(geometry.size.height)
                    let count = self.history.rawValues.count
                    if count > 0 {
                        let v = self.history.rawValues.map{$0.value}
                        let yScale = (height - 20.0) / self.yMax()
                        let xScale = width / Double(count - 1)
                        var startingVoid = v[count - 1] < 1 ? true : false
                        if startingVoid == false { path.move(to: .init(x: 0.0 + 30.0, y: height - Double(v[count - 1]) * yScale)) }
                        for i in 1 ..< count {
                            if v[count - i - 1] > 0 {
                                let point = CGPoint(x: Double(i) * xScale + 30.0, y: height - Double(v[count - i - 1]) * yScale)
                                if startingVoid == false {
                                    path.addLine(to: point)
                                } else {
                                    startingVoid = false
                                    path.move(to: point)
                                }
                            }
                        }
                    }
                }.stroke(Color.yellow).opacity(0.6)
            }


            // History calibrated raw values
            GeometryReader { geometry in
                Path() { path in
                    let width  = Double(geometry.size.width) - 60.0
                    let height = Double(geometry.size.height)
                    let count = self.history.calibratedValues.count
                    if count > 0 {
                        let v = self.history.calibratedValues.map{$0.value}
                        let yScale = (height - 20.0) / self.yMax()
                        let xScale = width / Double(count - 1)
                        var startingVoid = v[count - 1] < 1 ? true : false
                        if startingVoid == false { path.move(to: .init(x: 0.0 + 30.0, y: height - Double(v[count - 1]) * yScale)) }
                        for i in 1 ..< count {
                            if v[count - i - 1] > 0 {
                                let point = CGPoint(x: Double(i) * xScale + 30.0, y: height - Double(v[count - i - 1]) * yScale)
                                if startingVoid == false {
                                    path.addLine(to: point)
                                } else {
                                    startingVoid = false
                                    path.move(to: point)
                                }
                            }
                        }
                    }
                }.stroke(Color.purple).opacity(0.75)
            }


            // History (OOP) values
            GeometryReader { geometry in
                Path() { path in
                    let width  = Double(geometry.size.width) - 60.0
                    let height = Double(geometry.size.height)
                    path.addRoundedRect(in: CGRect(x: 0.0 + 30, y: 0.0, width: width, height: height), cornerSize: CGSize(width: 8, height: 8))
                    let count = self.history.values.count
                    if count > 0 {
                        let v = self.history.values.map{$0.value}
                        let yScale = (height - 20.0) / self.yMax()
                        let xScale = width / Double(count - 1)
                        var startingVoid = v[count - 1] < 1 ? true : false
                        if startingVoid == false { path.move(to: .init(x: 0.0 + 30.0, y: height - Double(v[count - 1]) * yScale)) }
                        for i in 1 ..< count {
                            if v[count - i - 1] > 0 {
                                let point = CGPoint(x: Double(i) * xScale + 30.0, y: height - Double(v[count - i - 1]) * yScale)
                                if startingVoid == false {
                                    path.addLine(to: point)
                                } else {
                                    startingVoid = false
                                    path.move(to: point)
                                }
                            }
                        }
                    }
                }.stroke(Color.blue)
            }
        }
    }
}


struct Graph_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .monitor))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
