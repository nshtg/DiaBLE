import Foundation
import SwiftUI


struct Details: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {

            Spacer()

            Form {

                if app.device == nil && app.sensor == nil {
                    HStack {
                        Spacer()
                        Text("No device connected").foregroundColor(.red)
                        Spacer()
                    }
                }

                if app.device != nil {
                    Section(header: Text("Device").font(.headline)) {
                        Group {
                            if app.device.peripheral?.name != nil {
                                HStack {
                                    Text("Name")
                                    Spacer()
                                    Text(app.device.peripheral!.name!).foregroundColor(.yellow)
                                }
                            }
                            if app.device.name != app.device.peripheral?.name ?? "Unnamed" {
                                HStack {
                                    Text("Type")
                                    Spacer()
                                    Text(app.device.name).foregroundColor(.yellow)
                                }
                            }
                        }
                        if !app.device.serial.isEmpty {
                            HStack {
                                Text("Serial")
                                Spacer()
                                Text(app.device.serial).foregroundColor(.yellow)
                            }
                        }
                        Group {
                            if !app.device.company.isEmpty && app.device.company != "< Unknown >" {
                                HStack {
                                    Text("Company")
                                    Spacer()
                                    Text(app.device.company).foregroundColor(.yellow)
                                }
                            }
                            if !app.device.manufacturer.isEmpty {
                                HStack {
                                    Text("Manufacturer")
                                    Spacer()
                                    Text(app.device.manufacturer).foregroundColor(.yellow)
                                }
                            }
                            if !app.device.model.isEmpty {
                                HStack {
                                    Text("Model")
                                    Spacer()
                                    Text(app.device.model).foregroundColor(.yellow)
                                }
                            }
                            if !app.device.firmware.isEmpty {
                                HStack {
                                    Text("Firmware")
                                    Spacer()
                                    Text(app.device.firmware).foregroundColor(.yellow)
                                }
                            }
                            if !app.device.hardware.isEmpty {
                                HStack {
                                    Text("Hardware")
                                    Spacer()
                                    Text(app.device.hardware).foregroundColor(.yellow)
                                }
                            }
                            if !app.device.software.isEmpty {
                                HStack {
                                    Text("Software")
                                    Spacer()
                                    Text(app.device.software).foregroundColor(.yellow)
                                }
                            }
                        }
                        if app.device.macAddress.count > 0 {
                            HStack {
                                Text("MAC Address")
                                Spacer()
                                Text(app.device.macAddress.hexAddress).foregroundColor(.yellow)
                            }
                        }
                        if app.device.rssi != 0 {
                            HStack {
                                Text("RSSI")
                                Spacer()
                                Text("\(app.device.rssi) dB").foregroundColor(.yellow)
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

                    }.font(.callout)
                }


                if app.sensor != nil {
                    Section(header: Text("Sensor").font(.headline)) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(app.sensor.state.description)
                                .foregroundColor(app.sensor.state == .active ? .green : .red)
                        }
                        HStack {
                            Text("Type")
                            Spacer()
                            Text("\(app.sensor.type.description)\(app.sensor.patchInfo.hex.hasPrefix("a2") ? " (A2 kind)" : "")").foregroundColor(.yellow)
                        }
                        if app.sensor.serial != "" {
                            HStack {
                                Text("Serial")
                                Spacer()
                                Text(app.sensor.serial).foregroundColor(.yellow)
                            }
                        }
                        if app.sensor.region != 0 {
                            HStack {
                                Text("Region")
                                Spacer()
                                Text("\(SensorRegion(rawValue: app.sensor.region)?.description ?? "unknown")").foregroundColor(.yellow)
                            }
                        }
                        if app.sensor.maxLife > 0 {
                            HStack {
                                Text("Maximum Life")
                                Spacer()
                                Text("\(Double(app.sensor.maxLife)/60/24, specifier: "%.2f") days").foregroundColor(.yellow)
                            }
                        }
                        if app.sensor.age > 0 {
                            HStack {
                                Text("Age")
                                Spacer()
                                Text("\(Double(app.sensor.age)/60/24, specifier: "%.2f") days").foregroundColor(.yellow)
                            }
                            HStack {
                                Text("Started on")
                                Spacer()
                                Text("\((app.lastReadingDate - Double(app.sensor.age) * 60).shortDateTime)").foregroundColor(.yellow)
                            }
                        }
                    }.font(.callout)
                }

                Section(header: Text("BLE Setup").font(.headline)) {

                    // TODO: hex <->  Data formatter
                    HStack {
                        Text("Sensor UID")
                        Spacer()
                        Text(settings.patchUid.hex).foregroundColor(.yellow)
                    }
                    HStack {
                        Text("Patch Info")
                        Spacer()
                        Text(settings.patchInfo.hex).foregroundColor(.yellow)
                    }
                    HStack {
                        Text("Calibration Info")
                        Spacer()
                        Text("[\(settings.activeSensorCalibrationInfo.i1), \(settings.activeSensorCalibrationInfo.i2), \(settings.activeSensorCalibrationInfo.i3), \(settings.activeSensorCalibrationInfo.i4), \(settings.activeSensorCalibrationInfo.i5), \(settings.activeSensorCalibrationInfo.i6)]")
                            .foregroundColor(.yellow)
                    }
                    HStack {
                        Text("Unlock Code")
                        TextField("Unlock Code", value: $settings.activeSensorUnlockCode, formatter: NumberFormatter()).multilineTextAlignment(.trailing).foregroundColor(.blue)
                    }
                    HStack {
                        Text("Unlock Count")
                        TextField("Unlock Count", value: $settings.activeSensorUnlockCount, formatter: NumberFormatter()).multilineTextAlignment(.trailing).foregroundColor(.blue)
                    }

                }.font(.callout)


                // Embed a specific device setup panel
                // if app.device?.type == Custom.type {
                //     CustomDetailsView(device: app.device as! Custom)
                //     .font(.callout)
                // }

            }


            Spacer()

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
            }.padding(.bottom, 8)

            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Details")
        }
        .foregroundColor(Color(UIColor.lightGray))
    }
}


struct Details_Preview: PreviewProvider {

    static var previews: some View {
        Group {
            Details()
                .environmentObject(AppState.test(tab: .monitor))
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
