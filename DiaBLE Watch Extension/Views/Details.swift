import Foundation
import SwiftUI


struct Details: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {

            Form {

                if app.device != nil {
                    Section(header: Text("Device").font(.footnote)) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text("\(app.device.name)").foregroundColor(.yellow)
                        }
                        if !app.device.serial.isEmpty {
                            HStack {
                                Text("Serial")
                                Spacer()
                                Text("\(app.device.serial)").foregroundColor(.yellow)
                            }
                        }
                        if !app.device.firmware.isEmpty {
                            HStack {
                                Text("Firmware")
                                Spacer()
                                Text("\(app.device.firmware)").foregroundColor(.yellow)
                            }
                        }
                        if !app.device.manufacturer.isEmpty {
                            HStack {
                                Text("Manufacturer")
                                Spacer()
                                Text("\(app.device.manufacturer)").foregroundColor(.yellow)
                            }
                        }
                        if !app.device.model.isEmpty {
                            HStack {
                                Text("Model")
                                Spacer()
                                Text("\(app.device.model)").foregroundColor(.yellow)
                            }
                        }
                        if !app.device.hardware.isEmpty {
                            HStack {
                                Text("Hardware")
                                Spacer()
                                Text("\(app.device.hardware)").foregroundColor(.yellow)
                            }
                        }
                        if !app.device.software.isEmpty {
                            HStack {
                                Text("Software")
                                Spacer()
                                Text("\(app.device.software)").foregroundColor(.yellow)
                            }
                        }
                        if app.device.macAddress.count > 0 {
                            HStack {
                                Text("MAC Address")
                                Spacer()
                                Text("\(app.device.macAddress.hexAddress)").foregroundColor(.yellow)
                            }
                        }
                        if app.device.battery > -1 {
                            HStack {
                                Text("Battery")
                                Spacer()
                                Text("\(app.device.battery)%")
                                    .foregroundColor(app.device.battery > 10 ? .green : .red)
                            }
                        }
                    }.font(.footnote)
                }


                if app.sensor != nil {
                    Section(header: Text("Sensor").font(.footnote)) {
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
                    }.font(.footnote)
                }


                //                if app.device?.type == Watlaa.type {
                //                    WatlaaDetailsView(device: app.device as! Watlaa)
                //                        .font(.footnote)
                //                }

                if app.device == nil && app.sensor == nil {
                    HStack {
                        Spacer()
                        Text("No device connected").foregroundColor(.red)
                        Spacer()
                    }
                }
            }

            // Spacer()

            VStack(spacing: 0) {
                // Same as Rescan
                // FIXME: updates only every 3-4 seconds
                Button(action: {
                    let centralManager = self.app.main.centralManager
                    if self.app.device != nil {
                        centralManager.cancelPeripheralConnection(self.app.device.peripheral!)
                    }
                    if centralManager.state == .poweredOn {
                        centralManager.scanForPeripherals(withServices: nil, options: nil)
                        self.app.main.info("\n\nScanning...")
                    }
                    if let healthKit = self.app.main.healthKit { healthKit.read() }
                    //                    if let nightscout = self.app.main.nightscout { nightscout.read() }
                }
                ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 16, height: 16)
                    .foregroundColor(.blue) }.frame(height: 16)

                Text(app.deviceState == "Connected" && (readingCountdown > 0 || app.info.hasSuffix("sensor")) ?
                    "\(readingCountdown) s" : "...")
                    .fixedSize()
                    .onReceive(timer) { _ in
                        self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                }.foregroundColor(.orange).font(Font.footnote.monospacedDigit())
            } //.padding(.bottom, 8)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle(Text("Details"))
        .foregroundColor(Color.init(UIColor.lightGray))
        .buttonStyle(PlainButtonStyle())
    }
}


struct Details_Preview: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            Details()
                .environmentObject(App.test(tab: .monitor))
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
