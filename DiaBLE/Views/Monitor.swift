import Foundation
import SwiftUI


struct Monitor: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var editingCalibration = false
    @State private var showingNFCAlert = false
    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {

            VStack {
                if !editingCalibration {
                    Spacer()
                }
                
                VStack {
                    HStack {
                        VStack {

                            Text("\(app.lastReadingDate.shortTime)")
                            Text("\(Int(Date().timeIntervalSince(app.lastReadingDate)/60)) min ago").font(.footnote)

                        }.frame(maxWidth: .infinity, alignment: .trailing ).padding(.trailing, 12).foregroundColor(Color.init(UIColor.lightGray))

                        // currentGlucose is negative when set to the last trend raw value (no online connection or calibration)
                        Text(app.currentGlucose > 0 ? "\(app.currentGlucose) " :
                            (app.currentGlucose < 0 ? "(\(-app.currentGlucose)) " : "--- "))
                            .fontWeight(.black)
                            .foregroundColor(.black)
                            .padding(10)
                            .background(abs(app.currentGlucose) > 0 && (abs(app.currentGlucose) > Int(settings.alarmHigh) || abs(app.currentGlucose) < Int(settings.alarmLow)) ? Color.red :
                                (app.currentGlucose < 0 ?
                                    (history.calibratedTrend.count > 0 ? Color.purple : Color.yellow) : Color.blue))
                            .cornerRadius(5)


                        Text(OOP.trendSymbol(for: app.oopTrend)).font(.largeTitle).bold().foregroundColor(.blue).bold().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
                    }

                    Text("\(app.oopAlarm.replacingOccurrences(of: "_", with: " ")) - \(app.oopTrend.replacingOccurrences(of: "_", with: " "))")
                        .foregroundColor(.blue)

                    HStack {
                        Text(app.deviceState)
                            .foregroundColor(app.deviceState == "Connected" ? .green : .red)
                            .fixedSize()

                        if app.deviceState == "Connected" {

                            Text(readingCountdown > 0 || app.info.hasSuffix("sensor") ?
                                "\(readingCountdown) s" : "")
                                .fixedSize()
                                .onReceive(timer) { _ in
                                    self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                            }.font(Font.callout.monospacedDigit()).foregroundColor(.orange)
                        }
                    }
                }


                Graph().frame(width: 31 * 7 + 60, height: 150)


                if !editingCalibration {

                    VStack {

                        HStack(spacing: 12) {

                            if app.sensor != nil && (app.sensor.state != .unknown || app.sensor.serial != "") {
                                VStack {
                                    Text(app.sensor.state.description)
                                        .foregroundColor(app.sensor.state == .ready ? .green : .red)

                                    if app.sensor.serial != "" {
                                        Text("\(app.sensor.serial)")
                                    }

                                    if app.sensor.age > 0 {
                                        Text("\(Double(app.sensor.age)/60/24, specifier: "%.1f") days")
                                    }
                                }
                            }

                            if app.device?.name != app.transmitter?.name && app.transmitter?.battery ?? -1 > -1 {
                                VStack {
                                    if app.transmitter.battery > -1 {
                                        Text("Battery: ").foregroundColor(Color.init(UIColor.lightGray)) +
                                            Text("\(app.transmitter.battery)%")
                                    }
                                    if app.transmitter.firmware.count > 0 {
                                        Text("Firmware: ").foregroundColor(Color.init(UIColor.lightGray)) +
                                            Text("\(app.transmitter.firmware)")
                                    }
                                    if app.transmitter.manufacturer.count + app.transmitter.hardware.count > 0  {
                                        Text("Hardware: ").foregroundColor(Color.init(UIColor.lightGray)) +
                                            Text("\(app.transmitter.manufacturer)\(app.transmitter.manufacturer == "" ? "" : "\n")\(app.transmitter.model) \(app.transmitter.hardware)")
                                    }
                                    if app.transmitter.macAddress.count > 0  {
                                        Text("\(app.transmitter.macAddress.hexAddress)")
                                    }
                                }
                            }

                            if app.device != nil {
                                VStack {
                                    if app.device.battery > -1 {
                                        Text("Battery:").foregroundColor(Color.init(UIColor.lightGray)) +
                                            Text("\(app.device.battery)%")
                                    }
                                    if app.device.firmware.count > 0 {
                                        Text("Firmware: ").foregroundColor(Color.init(UIColor.lightGray)) +
                                            Text("\(app.device.firmware)")
                                    }
                                    if app.device.manufacturer.count + app.device.hardware.count > 0  {
                                        Text("Hardware: ").foregroundColor(Color.init(UIColor.lightGray)) +
                                            Text("\(app.device.manufacturer)\(app.device.manufacturer == "" ? "" : "\n")\(app.device.model) \(app.device.hardware)")
                                    }
                                    if app.device.macAddress.count > 0  {
                                        Text("\(app.device.macAddress.hexAddress)")
                                    }
                                }
                            }

                        }.font(.footnote).foregroundColor(.yellow)

                        Text(app.info)
                            .font(.footnote)
                            .padding(.vertical, 5)

                        if app.info.hasPrefix("Scanning") {
                            Button(action: {
                                self.app.main.centralManager.stopScan()
                                self.app.main.info("\n\nStopped scanning")
                            }) { Image(systemName: "stop.circle").resizable().frame(width: 32, height: 32)
                            }.foregroundColor(.red)

                        }

                        if !app.info.contains("canning") {
                            NavigationLink(destination: Details(device: app.device)) {
                                Text("Details").font(.footnote).bold().fixedSize()
                                    .padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2))
                            }.disabled(self.app.device == nil && self.settings.preferredWatch == .none)
                        }
                    }

                    Spacer()

                }

                if history.calibratedValues.count > 0 {
                    VStack(spacing: 6) {
                        HStack {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Slope slope:")
                                    TextField("Slope slope", value: $app.calibration.slopeSlope, formatter: settings.numberFormatter, onEditingChanged: { changed in
                                        if changed {self.app.main.applyCalibration(sensor: self.app.sensor)
                                        }
                                    },
                                              onCommit: {
                                                self.editingCalibration = false
                                                self.app.main.applyCalibration(sensor: self.app.sensor)
                                    })
                                        .foregroundColor(.purple)
                                        .onTapGesture {
                                            self.editingCalibration = true
                                    }
                                }
                                if self.editingCalibration {
                                    Slider(value: $app.calibration.slopeSlope, in: 0.00001 ... 0.00002, step: 0.00000005)
                                        .accentColor(.purple)
                                }
                            }

                            VStack(spacing: 0) {
                                HStack {
                                    Text("Slope offset:")
                                    TextField("Slope offset", value: $app.calibration.offsetSlope, formatter: settings.numberFormatter, onEditingChanged: { changed in
                                        if changed {self.app.main.applyCalibration(sensor: self.app.sensor)
                                        }
                                    },
                                              onCommit: {
                                                self.editingCalibration = false
                                                self.app.main.applyCalibration(sensor: self.app.sensor)
                                    })
                                        .foregroundColor(.purple)
                                        .onTapGesture {
                                            self.editingCalibration = true
                                    }
                                }
                                if self.editingCalibration {
                                    Slider(value: $app.calibration.offsetSlope, in: -0.02 ... 0.02, step: 0.0001)
                                        .accentColor(.purple)
                                }
                            }
                        }

                        HStack {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Offset slope:")
                                    TextField("Offset slope", value: $app.calibration.slopeOffset, formatter: settings.numberFormatter, onEditingChanged: { changed in
                                        if changed {self.app.main.applyCalibration(sensor: self.app.sensor)
                                        }
                                    },
                                              onCommit: {
                                                self.editingCalibration = false
                                                self.app.main.applyCalibration(sensor: self.app.sensor)
                                    })
                                        .foregroundColor(.purple)
                                        .onTapGesture {
                                            self.editingCalibration = true
                                    }
                                }
                                if self.editingCalibration {
                                    Slider(value: $app.calibration.slopeOffset, in: -0.01 ... 0.01, step: 0.00005)
                                        .accentColor(.purple)
                                }
                            }

                            VStack(spacing: 0) {
                                HStack {
                                    Text("Offset offset:")
                                    TextField("Offset offset", value: $app.calibration.offsetOffset, formatter: settings.numberFormatter,
                                              onEditingChanged: { changed in
                                                if changed {self.app.main.applyCalibration(sensor: self.app.sensor)
                                                }
                                    },
                                              onCommit: {
                                                self.editingCalibration = false
                                                self.app.main.applyCalibration(sensor: self.app.sensor)
                                    })
                                        .foregroundColor(.purple)
                                        .onTapGesture {
                                            self.editingCalibration = true
                                    }
                                }
                                if self.editingCalibration {
                                    Slider(value: $app.calibration.offsetOffset, in: -100 ... 100, step: 0.5)
                                        .accentColor(.purple)
                                }
                            }
                        }
                        if self.editingCalibration {
                            Spacer()
                            Button(action: {
                                self.editingCalibration = false
                            }
                            ) { Text("Close").bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)).accentColor(.purple) }
                            Spacer()
                        }
                    }
                    .font(.footnote)
                    .keyboardType(.numbersAndPunctuation)
                }

                Spacer()

                // Same as Rescan
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
                ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 32, height: 32).padding(.bottom, 8).foregroundColor(.accentColor) }

            }
            .multilineTextAlignment(.center)
            .navigationBarTitle("DiaBLE  \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String)  -  Monitor", displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: {
                    if self.app.main.nfcReader.isNFCAvailable {
                        self.app.main.nfcReader.startSession()
                    } else {
                        self.showingNFCAlert = true
                    }
                }) { VStack(spacing: 0) {
                    Image(systemName: "radiowaves.left")
                        .resizable().rotationEffect(.degrees(90)).frame(width: 16, height: 32).offset(y: 8)
                    Text("NFC").font(.footnote).bold()
                    Text("  Scan  ").font(.footnote).offset(y: -4)
                    }
                }.alert(isPresented: $showingNFCAlert) {
                    Alert(
                        title: Text("NFC not supported"),
                        message: Text("This device doesn't allow scanning the Libre."))
                }
            )
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}


struct Monitor_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .monitor))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
