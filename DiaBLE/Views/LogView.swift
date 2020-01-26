import Foundation
import SwiftUI


struct LogView: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var info: Info
    @EnvironmentObject var log: Log
    @EnvironmentObject var settings: Settings

    @State private var showingNFCAlert = false
    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(showsIndicators: true) {
                Text(log.text)
                    .font(.system(.footnote, design: .monospaced)).foregroundColor(Color.init(UIColor.lightGray))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(4)
            }

            VStack(alignment: .center, spacing: 8) {

                VStack(spacing: 0) {

                    Button(action: {
                        if self.app.main.nfcReader.isNFCAvailable {
                            self.app.main.nfcReader.startSession()
                        } else {
                            self.showingNFCAlert = true
                        }
                    }) { VStack {
                        Image(systemName: "radiowaves.left")
                            .resizable()
                            .rotationEffect(.degrees(90))
                            .frame(width: 16, height: 32)
                        Text("NFC").bold().offset(y: -16)
                        }
                    }.alert(isPresented: $showingNFCAlert) {
                        Alert(
                            title: Text("NFC not supported"),
                            message: Text("This device doesn't allow scanning the Libre."))
                    }

                    // Same as Rescan
                    Button(action: {
                        let transmitter = self.app.transmitter
                        let centralManager = self.app.main.centralManager
                        if transmitter != nil {
                            centralManager.cancelPeripheralConnection(transmitter!.peripheral!)
                        }
                        if centralManager.state == .poweredOn {
                            centralManager.scanForPeripherals(withServices: nil, options: nil)
                        }
                        if let healthKit = self.app.main.healthKit { healthKit.read() }
                    }
                    ) { VStack { Image("Bluetooth").resizable().frame(width: 32, height: 32)
                        Text("Scan")
                        }
                    }
                }.foregroundColor(.accentColor)

                if app.transmitterState == "Connected" {

                    Text(readingCountdown > 0 || info.text.hasSuffix("sensor") ?
                        "\(readingCountdown) s" : "")
                        .fixedSize()
                        .onReceive(timer) { _ in
                            self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                    }.font(Font.caption.monospacedDigit()).foregroundColor(.orange)
                }

                Spacer()

                Button(action: {
                    self.settings.debugLevel = 1 - self.settings.debugLevel
                }) { VStack {
                    Image(systemName: "wrench.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text(settings.debugLevel == 1 ? "Devel" : "Basic").font(.caption).offset(y: -6)
                    }
                }.background(settings.debugLevel == 1 ? Color.accentColor : Color.clear)
                    .foregroundColor(settings.debugLevel == 1 ? .black : .accentColor)
                    .padding(.bottom, 6)

                Button(action: { UIPasteboard.general.string = self.log.text }) {
                    VStack {
                        Image(systemName: "doc.on.doc")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Copy").offset(y: -6)
                    }
                }

                Button(action: { self.log.text = "Log cleared \(Date().local)\n" }) {
                    VStack {
                        Image(systemName: "clear")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Clear").offset(y: -6)
                    }
                }

                Button(action: {
                    self.settings.reversedLog.toggle()
                    self.log.text = self.log.text.split(separator:"\n").reversed().joined(separator: "\n")
                    if !self.settings.reversedLog { self.log.text.append(" \n") }
                }) { VStack {
                    Image(systemName: "backward.fill")
                        .resizable()
                        .frame(width: 12, height: 12).offset(y: 5)
                    Text(" REV ").offset(y: -2)
                    }
                }.background(settings.reversedLog ? Color.accentColor : Color.clear)
                    .border(Color.accentColor, width: 3)
                    .cornerRadius(5)
                    .foregroundColor(settings.reversedLog ? .black : .accentColor)


                Button(action: {
                    self.settings.logging.toggle()
                    self.app.main.log("\(self.settings.logging ? "Log started" : "Log stopped") \(Date().local)")
                }) { VStack {
                    Image(systemName: settings.logging ? "stop.circle" : "play.circle")
                        .resizable()
                        .frame(width: 32, height: 32)
                    }
                }.foregroundColor(settings.logging ? .red : .green)

                Spacer()

            }.font(.system(.footnote))
        }.background(Color.black)
    }
}



struct LogView_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var info: Info
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .log))
                .environmentObject(Info.test)
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}

