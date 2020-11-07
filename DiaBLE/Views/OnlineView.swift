import Foundation
import SwiftUI


struct OnlineView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var showingNFCAlert = false
    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    var body: some View {
        NavigationView {

            // Workaround to avoid top textfields scrolling offscreen in iOS 14
            GeometryReader { _ in
                VStack(spacing: 0) {

                    HStack {
                        Image("Nightscout").resizable().frame(width: 32, height: 32).shadow(color: Color(UIColor.cyan), radius: 4.0 )
                        VStack(spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("https://").foregroundColor(Color(UIColor.lightGray))
                                TextField("Nightscout URL", text: $settings.nightscoutSite)
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text("token:").foregroundColor(Color(UIColor.lightGray))
                                SecureField("token", text: $settings.nightscoutToken)
                            }
                        }

                        VStack(spacing: 0) {
                            // TODO: reload web page
                            // Same as Rescan
                            Button(action: {
                                let device = self.app.device
                                let centralManager = self.app.main.centralManager
                                if device != nil {
                                    centralManager.cancelPeripheralConnection(device!.peripheral!)
                                }
                                if centralManager.state == .poweredOn {
                                    centralManager.scanForPeripherals(withServices: nil, options: nil)
                                    self.app.main.status("Scanning...")
                                }
                                if let healthKit = self.app.main.healthKit { healthKit.read() }
                                if let nightscout = self.app.main.nightscout { nightscout.read() }
                            }
                            ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 32, height: 32)
                                .foregroundColor(.accentColor) }

                            Text(app.deviceState == "Connected" && (readingCountdown > 0 || app.status.hasSuffix("sensor")) ?
                                    "\(readingCountdown) s" : "...")
                                .fixedSize()
                                .onReceive(timer) { _ in
                                    self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                                }.foregroundColor(.orange).font(Font.caption.monospacedDigit())
                        }

                        Button(action: {
                            if self.app.main.nfcReader.isNFCAvailable {
                                self.app.main.nfcReader.startSession()
                                if let healthKit = self.app.main.healthKit { healthKit.read() }
                                if let nightscout = self.app.main.nightscout { nightscout.read() }
                            } else {
                                self.showingNFCAlert = true
                            }
                        }) {
                            Image("NFC").renderingMode(.template).resizable().frame(width: 39, height: 27).padding(.bottom, 12)
                        }.alert(isPresented: $showingNFCAlert) {
                            Alert(
                                title: Text("NFC not supported"),
                                message: Text("This device doesn't allow scanning the Libre."))
                        }

                    }.foregroundColor(.accentColor)
                    .padding(.bottom, 4)


                    WebView(site: settings.nightscoutSite, query: "token=\(settings.nightscoutToken)", delegate: app.main?.nightscout )
                        .frame(height: UIScreen.main.bounds.size.height * 0.60)
                        .alert(isPresented: $app.showingJavaScriptConfirmAlert) {
                            Alert(title: Text("JavaScript"),
                                  message: Text(self.app.JavaScriptConfirmAlertMessage),
                                  primaryButton: .default(Text("OK")) {
                                    self.app.main.log("JavaScript alert: selected OK") },
                                  secondaryButton: .cancel(Text("Cancel")) {
                                    self.app.main.log("JavaScript alert: selected Cancel") }
                            )
                        }

                    List {
                        ForEach(history.nightscoutValues) { glucose in
                            (Text("\(String(glucose.source[..<(glucose.source.lastIndex(of: " ") ?? glucose.source.endIndex)])) \(glucose.date.shortDateTime)") + Text("  \(glucose.value, specifier: "%3d")").bold())
                                .fixedSize(horizontal: false, vertical: true).listRowInsets(EdgeInsets())
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }.font(.system(.caption, design: .monospaced)).foregroundColor(Color(UIColor.cyan))
                    .onAppear { if let nightscout = self.app.main?.nightscout { nightscout.read() } }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Online")
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}


struct OnlineView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(AppState.test(tab: .online))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
