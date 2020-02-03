import Foundation
import SwiftUI


struct OnlineView: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                HStack {
                    Image("Nightscout").resizable().frame(width: 32, height: 32).shadow(color: Color.init(UIColor.cyan), radius: 4.0 )
                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("https://").foregroundColor(Color.init(UIColor.lightGray))
                            TextField("Nightscout URL", text: $settings.nightscoutSite)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("token:").foregroundColor(Color.init(UIColor.lightGray))
                            SecureField("token", text: $settings.nightscoutToken)
                        }
                    }

                    VStack(spacing: 0) {
                        Button(action: {

                            // TODO: reload

                        }
                        ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 32, height: 32) }

                        if app.transmitterState == "Connected" {
                            Text(readingCountdown > 0 || app.info.hasSuffix("sensor") ?
                                "\(readingCountdown) s" : "")
                                .fixedSize()
                                .onReceive(timer) { _ in
                                    self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                            }.foregroundColor(.orange).font(Font.caption.monospacedDigit())
                        }
                    }
                }.foregroundColor(.accentColor)
                    .padding(.bottom, 4)

                WebView(site: settings.nightscoutSite, query: "token=\(settings.nightscoutToken)")

                if history.nightscoutValues.count > 0 {
                    VStack(spacing: 0) {
                        List() {
                            ForEach(history.nightscoutValues) { glucose in
                                Text("\(String(glucose.source[..<(glucose.source.lastIndex(of: " ") ?? glucose.source.endIndex)])) \(glucose.date.shortDateTime)  \(String(format: "%3d", Int(glucose.value)))")
                                    .fixedSize(horizontal: false, vertical: true).listRowInsets(EdgeInsets())
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }.font(.system(.caption, design: .monospaced)).foregroundColor(.blue)
                        .onAppear { if let nightscout = self.app.main?.nightscout { nightscout.read() } }
                }
            }
            .navigationBarTitle("TODO:  Online", displayMode: .inline)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}


struct OnlineView_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .online))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
