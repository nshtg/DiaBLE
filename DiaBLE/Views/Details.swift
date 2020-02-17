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

            if device != nil {
                VStack {
                    Text("Device name: ") +
                        Text("\(device!.name)").foregroundColor(.yellow)
                    if !device!.serial.isEmpty {
                        Text("Serial: ") +
                            Text("\(device!.serial)").foregroundColor(.yellow)
                    }
                    if !device!.firmware.isEmpty {
                        Text("Firmware: ") +
                            Text("\(device!.firmware)").foregroundColor(.yellow)
                    }
                    if device!.manufacturer.count + device!.model.count + device!.hardware.count > 0 {
                        Text("Hardware: ") +
                            Text("\(device!.manufacturer) \(device!.model) \(device!.hardware)").foregroundColor(.yellow)
                    }
                    if !device!.software.isEmpty {
                        Text("Software: ") +
                            Text("\(device!.software)").foregroundColor(.yellow)
                    }
                    if (device!.macAddress.count > 0) {
                        Text("MAC Address: ") +
                            Text("\(device!.macAddress.hexAddress)").foregroundColor(.yellow)
                    }
                }.font(.callout)

                Spacer()

            }

            if device != nil {
                if device!.battery > -1 {
                    Text("Battery: \(device!.battery)%")
                        .foregroundColor(.green)
                }
                Spacer()
            }

            // Same as Monitor
            if app.sensor != nil && (app.sensor.state != .unknown || app.sensor.serial != "") {
                VStack {
                    Text("Sensor type: ") +
                        Text("\(app.sensor.type.description)").foregroundColor(.yellow)

                    Text("\(app.sensor.state.description)")
                        .foregroundColor(app.sensor.state == .ready ? .green : .red)

                    if app.sensor.serial != "" {
                        Text("Serial: ") +
                            Text("\(app.sensor.serial)").foregroundColor(.yellow)
                    }

                    if app.sensor.age > 0 {
                        Text("Age: ") +
                            Text("\(Double(app.sensor.age)/60/24, specifier: "%.1f") days").foregroundColor(.yellow)
                        Text("Started on: ") +
                            Text("\((app.lastReadingDate - Double(app.sensor.age) * 60).shortDateTime)").foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()

            VStack {
                if device?.type == Watlaa.type {
                    WatlaaDetailsView(device: device as! Watlaa)
                }
            }.font(.callout)

            Spacer()

            VStack(spacing: 0) {
                // Same as Rescan
                // FIXME: updates only every 3-4 seconds
                Button(action: {
                    let centralManager = self.app.main.centralManager
                    if self.device != nil {
                        centralManager.cancelPeripheralConnection(self.device!.peripheral!)
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
            }.padding(.bottom, 8)
                .navigationBarTitle(Text("Details"), displayMode: .inline)
        }
        .foregroundColor(Color.init(UIColor.lightGray))
    }
}


struct Details_Preview: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            NavigationView {
                Details(device: Watlaa())
                    .environmentObject(App.test(tab: .monitor))
                    .environmentObject(Settings())
                    .environment(\.colorScheme, .dark)
            }
        }
    }
}
