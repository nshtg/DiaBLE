import Foundation
import SwiftUI


struct Details: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var settings: Settings

    @State var device: Device?
    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {

            Spacer()

            Form {
                if device != nil {
                    Section(header: Text("Device").font(.headline)) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text("\(device!.name)").foregroundColor(.yellow)
                        }
                        if !device!.serial.isEmpty {
                            HStack {
                                Text("Serial")
                                Spacer()
                                Text("\(device!.serial)").foregroundColor(.yellow)
                            }
                        }
                        if !device!.firmware.isEmpty {
                            HStack {
                                Text("Firmware")
                                Spacer()
                                Text("\(device!.firmware)").foregroundColor(.yellow)
                            }
                        }
                        if !device!.manufacturer.isEmpty {
                            HStack {
                                Text("Manufacturer")
                                Spacer()
                                Text("\(device!.manufacturer)").foregroundColor(.yellow)
                            }
                        }
                        if !device!.model.isEmpty {
                            HStack {
                                Text("Model")
                                Spacer()
                                Text("\(device!.model)").foregroundColor(.yellow)
                            }
                        }
                        if !device!.hardware.isEmpty {
                            HStack {
                                Text("Hardware")
                                Spacer()
                                Text("\(device!.hardware)").foregroundColor(.yellow)
                            }
                        }
                        if !device!.software.isEmpty {
                            HStack {
                                Text("Software")
                                Spacer()
                                Text("\(device!.software)").foregroundColor(.yellow)
                            }
                        }
                        if device!.macAddress.count > 0 {
                            HStack {
                                Text("MAC address")
                                Spacer()
                                Text("\(device!.macAddress.hexAddress)").foregroundColor(.yellow)
                            }
                        }
                        if device!.battery > -1 {
                            HStack {
                                Text("Battery")
                                Spacer()
                                Text("\(device!.battery)%")
                                    .foregroundColor(device!.battery > 10 ? .green : .red)
                            }
                        }
                    }.font(.callout)

                }


                if app.sensor != nil {
                    Section(header: Text("Sensor").font(.headline)) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("\(app.sensor.state.description)")
                                .foregroundColor(app.sensor.state == .ready ? .green : .red)
                        }
                        HStack {
                            Text("Type")
                            Spacer()
                            Text("\(app.sensor.type.description)").foregroundColor(.yellow)
                        }
                        if app.sensor.serial != "" {
                            HStack {
                                Text("Serial")
                                Spacer()
                                Text("\(app.sensor.serial)").foregroundColor(.yellow)
                            }
                        }
                        if app.sensor.age > 0 {
                            HStack {
                                Text("Age")
                                Spacer()
                                Text("\(Double(app.sensor.age)/60/24, specifier: "%.1f") days").foregroundColor(.yellow)
                            }
                            HStack {
                                Text("Started on")
                                Spacer()
                                Text("\((app.lastReadingDate - Double(app.sensor.age) * 60).shortDateTime)").foregroundColor(.yellow)
                            }
                        }
                    }
                }


                if device?.type == Watlaa.type {
                    WatlaaDetailsView(device: device as! Watlaa)
                        .font(.callout)
                }
            }


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
            Details(device: Watlaa())
                .environmentObject(App.test(tab: .monitor))
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
