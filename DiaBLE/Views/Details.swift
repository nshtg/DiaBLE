import Foundation
import SwiftUI


struct Details: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var device: Device?
    
    var body: some View {

        VStack {
            Spacer()

            Text("TODO: \(device?.name ?? "Details")")

            Spacer()

            VStack(spacing: 32) {
                VStack {
                    Text("Device name: \(device!.name)")
                    Text("Firmware: \(device!.firmware)")
                    Text("Hardware: \(device!.manufacturer) \(device!.model) \(device!.hardware)")
                    Text("MAC Address: \(device!.macAddress.hexAddress)")
                }.font(.footnote).foregroundColor(.yellow)

                Text("Battery: \(device!.battery)%")
                    .foregroundColor(.green)
            }

            Spacer()
            VStack {
                if device?.type == Watlaa.type {
                    WatlaaDetailsView(device: device!)
                }
            }.foregroundColor(.blue)
            Spacer()

            VStack(spacing: 0) {
                // Same as Rescan
                // FIXME: updates only every 3-4 seconds
                Button(action: {
                    let device = self.app.device
                    let centralManager = self.app.main.centralManager
                    if device != nil {
                        centralManager.cancelPeripheralConnection(device!.peripheral!)
                    }
                    if centralManager.state == .poweredOn {
                        centralManager.scanForPeripherals(withServices: nil, options: nil)
                        self.app.main.info("\n\nScanning...")
                    }
                    if let healthKit = self.app.main.healthKit { healthKit.read() }
                    if let nightscout = self.app.main.nightscout { nightscout.read() }
                }
                ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 32, height: 32)
                    .foregroundColor(.accentColor) }

                Text(app.deviceState == "Connected" && (readingCountdown > 0 || app.info.hasSuffix("sensor")) ?
                    "\(readingCountdown) s" : "...")
                    .fixedSize()
                    .onReceive(timer) { _ in
                        self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                }.foregroundColor(.orange).font(Font.caption.monospacedDigit())
            }
        }
        .navigationBarTitle(Text("Details"), displayMode: .inline)
    }
}

struct Details_Preview: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .settings))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
