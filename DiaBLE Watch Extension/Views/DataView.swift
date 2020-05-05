import Foundation
import SwiftUI


struct DataView: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    var body: some View {
        ScrollView {
            VStack {

                Text("\(Date().dateTime)")
                    .foregroundColor(.white)

                if app.deviceState == "Connected" {
                    Text(readingCountdown > 0 || app.info.hasSuffix("sensor") ?
                        "\(readingCountdown) s" : "")
                        .fixedSize()
                        .onReceive(timer) { _ in
                            self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                    }.font(Font.footnote.monospacedDigit()).foregroundColor(.orange)
                }

                VStack {
                    HStack {
                        if history.values.count > 0 {
                            VStack(spacing: 4) {
                                Text("OOP history")
                                ScrollView {
                                    ForEach(history.values) { glucose in
                                        (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(Int(glucose.value), specifier: "%3lld")").bold()).padding(.vertical, 4)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .topLeading)
                            }.foregroundColor(.blue)
                        }

                        if history.rawValues.count > 0 {
                            VStack(spacing: 4) {
                                Text("Raw history")
                                ScrollView {
                                    ForEach(history.rawValues) { glucose in
                                        (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(Int(glucose.value), specifier: "%3lld")").bold()).padding(.vertical, 4)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .topLeading)
                            }.foregroundColor(.yellow)
                        }
                    }

                    HStack {
                        if history.calibratedValues.count > 0 {
                            VStack(spacing: 4) {
                                Text("Calibrated history")
                                ScrollView {
                                    ForEach(history.calibratedValues) { glucose in
                                        (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(Int(glucose.value), specifier: "%3lld")").bold()).padding(.vertical, 4)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .topLeading)
                            }.foregroundColor(.purple)
                        }

                        VStack {

                            if history.rawTrend.count > 0 {
                                VStack(spacing: 4) {
                                    Text("Raw trend")
                                    ScrollView {
                                        ForEach(history.rawTrend) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(Int(glucose.value), specifier: "%3lld")").bold()).padding(.vertical, 4)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.yellow)
                            }

                            if history.calibratedTrend.count > 0 {
                                VStack(spacing: 4) {
                                    Text("Calibrated trend")
                                    ScrollView {
                                        ForEach(history.calibratedTrend) { glucose in
                                            (Text("\(glucose.id) \(glucose.date.shortDateTime)") + Text("  \(Int(glucose.value), specifier: "%3lld")").bold()).padding(.vertical, 4)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.foregroundColor(.purple)
                            }
                        }
                    }

                    HStack(spacing: 0) {
                        if history.storedValues.count > 0 {
                            VStack(spacing: 0) {
                                Text("HealthKit")
                                List() {
                                    ForEach(history.storedValues) { glucose in
                                        (Text("\(String(glucose.source[..<(glucose.source.lastIndex(of: " ") ?? glucose.source.endIndex)])) \(glucose.date.shortDateTime)") + Text("  \(Int(glucose.value), specifier: "%3lld")").bold())
                                            .fixedSize(horizontal: false, vertical: true).listRowInsets(EdgeInsets()).listRowInsets(EdgeInsets())
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            }.foregroundColor(.red)
                                .onAppear { if let healthKit = self.app.main?.healthKit { healthKit.read() } }
                        }

                        if history.nightscoutValues.count > 0 {
                            VStack(spacing: 0) {
                                Text("Nightscout")
                                List() {
                                    ForEach(history.nightscoutValues) { glucose in
                                        (Text("\(String(glucose.source[..<(glucose.source.lastIndex(of: " ") ?? glucose.source.endIndex)])) \(glucose.date.shortDateTime)") + Text("  \(Int(glucose.value), specifier: "%3lld")").bold())
                                            .fixedSize(horizontal: false, vertical: true).listRowInsets(EdgeInsets())
                                    }
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                            }
                            .foregroundColor(.blue)
                            .onAppear { if let nightscout = self.app.main?.nightscout { nightscout.read() } }
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Data")
        .edgesIgnoringSafeArea([.bottom])
            // .font(.system(.footnote, design: .monospaced)).foregroundColor(Color(UIColor.lightGray))
            .font(.footnote).foregroundColor(Color(UIColor.lightGray))
    }
}


struct DataView_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            DataView()
                .environmentObject(App.test(tab: .data))
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
