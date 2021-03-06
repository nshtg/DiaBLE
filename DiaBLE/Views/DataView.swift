import Foundation
import SwiftUI


struct DataView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    var body: some View {
        NavigationView {
            VStack {

                Text("\(Date().dateTime)")
                    .foregroundColor(.white)

                if app.deviceState == "Connected" {
                    Text(readingCountdown > 0 || app.status.hasSuffix("sensor") ?
                            "\(readingCountdown) s" : "")
                        .fixedSize()
                        .onReceive(timer) { _ in
                            self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                        }.font(Font.caption.monospacedDigit()).foregroundColor(.orange)
                }

                VStack {

                    HStack {

                        VStack {

                            if history.values.count > 0 {
                                VStack(spacing: 4) {
                                    Text("OOP history").bold()
                                    ScrollView {
                                        ForEach(history.values) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.blue)
                            }

                            if history.factoryValues.count > 0 {
                                VStack(spacing: 4) {
                                    Text("History").bold()
                                    ScrollView {
                                        ForEach(history.factoryValues) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.orange)
                            }

                        }

                        if history.rawValues.count > 0 {
                            VStack(spacing: 4) {
                                Text("Raw history").bold()
                                ScrollView {
                                    ForEach(history.rawValues) { glucose in
                                        (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                    }
                                }.frame(maxWidth: .infinity, alignment: .topLeading)
                            }.foregroundColor(.yellow)
                        }
                    }

                    HStack {

                        VStack {

                            if history.factoryTrend.count > 0 {
                                VStack(spacing: 4) {
                                    Text("Trend").bold()
                                    ScrollView {
                                        ForEach(history.factoryTrend) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.orange)
                            }

                            if history.calibratedValues.count > 0 {
                                VStack(spacing: 4) {
                                    Text("Calibrated history").bold()
                                    ScrollView {
                                        ForEach(history.calibratedValues) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.purple)
                            }

                        }

                        VStack {

                            if history.rawTrend.count > 0 {
                                VStack(spacing: 4) {
                                    Text("Raw trend").bold()
                                    ScrollView {
                                        ForEach(history.rawTrend) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.yellow)
                            }

                            if history.calibratedTrend.count > 0 {
                                VStack(spacing: 4) {
                                    Text("Calibrated trend").bold()
                                    ScrollView {
                                        ForEach(history.calibratedTrend) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.purple)
                            }
                        }
                    }

                    HStack(spacing: 0) {

                        if history.storedValues.count > 0 {
                            VStack(spacing: 4) {
                                Text("HealthKit").bold()
                                List {
                                    ForEach(history.storedValues) { glucose in
                                        (Text("\(String(glucose.source[..<(glucose.source.lastIndex(of: " ") ?? glucose.source.endIndex)])) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                            .fixedSize(horizontal: false, vertical: true).listRowInsets(EdgeInsets()).listRowInsets(EdgeInsets())
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            }.foregroundColor(.red)
                            .onAppear { if let healthKit = self.app.main?.healthKit { healthKit.read() } }
                        }

                        if history.nightscoutValues.count > 0 {
                            VStack(spacing: 4) {
                                Text("Nightscout").bold()
                                List {
                                    ForEach(history.nightscoutValues) { glucose in
                                        (Text("\(String(glucose.source[..<(glucose.source.lastIndex(of: " ") ?? glucose.source.endIndex)])) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                            .fixedSize(horizontal: false, vertical: true).listRowInsets(EdgeInsets())
                                    }
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                            }.foregroundColor(Color(UIColor.cyan))
                            .onAppear { if let nightscout = self.app.main?.nightscout { nightscout.read() } }
                        }
                    }
                }
            }
            .font(.system(.caption, design: .monospaced)).foregroundColor(Color(UIColor.lightGray))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Data")

        }.navigationViewStyle(StackNavigationViewStyle())
    }
}


struct DataView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(AppState.test(tab: .data))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
