import Foundation
import SwiftUI


struct Details: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var device: Device?
    
    var body: some View {
        VStack {

            Spacer()

            Text("TODO: \(device?.name ?? "Details")")

            Spacer()

            VStack {
                Text("Device name: \(device!.name)")
                if !device!.firmware.isEmpty {
                    Text("Firmware: \(device!.firmware)")
                }
                if device!.manufacturer.count + device!.model.count + device!.hardware.count > 0 {
                    Text("Hardware: \(device!.manufacturer) \(device!.model) \(device!.hardware)")
                }
                if !device!.software.isEmpty {
                    Text("Software: \(device!.software)")
                }
                if (device!.macAddress.count > 0) {
                    Text("MAC Address: \(device!.macAddress.hexAddress)")
                }
            }.font(.footnote).foregroundColor(.yellow)

            Spacer()

            if device!.battery > -1 {
                Text("Battery: \(device!.battery)%")
                    .foregroundColor(.green)
            }

            Spacer()

            VStack {
                if device?.type == Watlaa.type {
                    WatlaaDetailsView(device: device as! Watlaa)
                }
            }.font(.callout).foregroundColor(Color.init(UIColor.lightGray))

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
            .navigationBarTitle(Text("Details"), displayMode: .inline)
        }
    }
}


struct Details_Preview: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            Details(device: Watlaa())
                .environmentObject(App.test(tab: .monitor))
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
