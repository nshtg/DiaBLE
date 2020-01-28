import Foundation
import SwiftUI


struct DataView: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var info: Info
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    var body: some View {
        NavigationView {
            VStack {

                if app.transmitterState == "Connected" {
                    Text("\(Date().dateTime)")
                        .foregroundColor(.white)

                    Text(readingCountdown > 0 || info.text.hasSuffix("sensor") ?
                        "\(readingCountdown) s" : "")
                        .fixedSize()
                        .onReceive(timer) { _ in
                            self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                    }.font(Font.caption.monospacedDigit()).foregroundColor(.orange)
                }

                VStack {
                    HStack {
                        if history.values.count > 0 {
                            VStack {
                                Text("OOP history")
                                ScrollView {
                                    ForEach(history.values) { glucose in
                                        Text("\(String(glucose.id))  \(glucose.date.shortDateTime)   \(String(glucose.value))")
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                            }.foregroundColor(.blue)
                        }

                        if history.rawValues.count > 0 {
                            VStack {
                                Text("Raw history")
                                ScrollView {
                                    ForEach(history.rawValues) { glucose in
                                        Text("\(String(glucose.id))  \(glucose.date.shortDateTime)   \(String(glucose.value))")
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                            }.foregroundColor(.yellow)
                        }
                    }

                    HStack {
                        if history.calibratedValues.count > 0 {
                            VStack {
                                Text("Calibrated history")
                                ScrollView {
                                    ForEach(history.calibratedValues) { glucose in
                                        Text("\(String(glucose.id))  \(glucose.date.shortDateTime)   \(String(glucose.value))")
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                            }.foregroundColor(.purple)
                        }

                        if history.calibratedTrend.count > 0 {
                            VStack {
                                Text("Calibrated trend")
                                ScrollView {
                                    ForEach(history.calibratedTrend) { glucose in
                                        Text("\(String(glucose.id))  \(glucose.date.shortDateTime)   \(String(glucose.value))")
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                            }.foregroundColor(.purple)
                        }
                    }

                    if history.storedValues.count > 0 {
                        VStack {
                            Text("HealthKit")
                            List(history.storedValues) { glucose in
                                Text("\(String(glucose.source[..<glucose.source.lastIndex(of: " ")!])) \(glucose.date.shortDateTime)   \(String(glucose.value))")
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }.onAppear { if let healthKit = self.app.main?.healthKit { healthKit.read() } }
                        }.foregroundColor(.red)
                    }
                }
            }
            .font(Font.footnote.monospacedDigit())
            .navigationBarTitle("TODO:  Data", displayMode: .inline)

        }.navigationViewStyle(StackNavigationViewStyle())
    }
}


struct DataView_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var info: Info
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .data))
                .environmentObject(Info.test)
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
