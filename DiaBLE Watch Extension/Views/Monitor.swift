import Foundation
import SwiftUI


struct Monitor: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var editingCalibration = false
    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {

        VStack(spacing: 0) {

            VStack(spacing: 0) {
                HStack {
                    VStack(spacing: 0) {

                        Text("\(app.lastReadingDate.shortTime)")
                        Text("\(Int(Date().timeIntervalSince(app.lastReadingDate)/60)) min ago").font(.system(size: 10)).lineLimit(1)

                    }.font(.footnote).frame(maxWidth: .infinity, alignment: .trailing ).foregroundColor(Color(UIColor.lightGray))

                    // currentGlucose is negative when set to the last trend raw value (no online connection or calibration)
                    Text(app.currentGlucose > 0 ? "\(app.currentGlucose) " :
                        (app.currentGlucose < 0 ? "(\(-app.currentGlucose)) " : "--- "))
                        .fontWeight(.black)
                        .foregroundColor(.black)
                        .padding(.vertical, 10).padding(.horizontal, app.currentGlucose > 0 ? 10 : 4)
                        .background(abs(app.currentGlucose) > 0 && (abs(app.currentGlucose) > Int(settings.alarmHigh) || abs(app.currentGlucose) < Int(settings.alarmLow)) ? Color.red :
                            (app.currentGlucose < 0 ?
                                (history.calibratedTrend.count > 0 ? Color.purple : Color.yellow) : Color.blue))
                        .cornerRadius(5)


                    Text(OOP.trendSymbol(for: app.oopTrend)).font(.system(size: 28)).bold().foregroundColor(.blue).bold().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 6).padding(.bottom, -18)
                }

                Text("\(app.oopAlarm.replacingOccurrences(of: "_", with: " ")) - \(app.oopTrend.replacingOccurrences(of: "_", with: " "))")
                    .font(.footnote).foregroundColor(.blue).lineLimit(1)

                HStack {
                    Text(app.deviceState)
                        .foregroundColor(app.deviceState == "Connected" ? .green : .red)
                        .font(.footnote).fixedSize()

                    if app.deviceState == "Connected" {

                        Text(readingCountdown > 0 || app.info.hasSuffix("sensor") ?
                            "\(readingCountdown) s" : "")
                            .fixedSize()
                            .onReceive(timer) { _ in
                                self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                        }.font(Font.footnote.monospacedDigit()).foregroundColor(.orange)
                    }
                }
            }


            Graph().frame(width: 31 * 4 + 60, height: 80)


            if !editingCalibration {

                VStack(spacing: 0) {

                    HStack(spacing: 2) {

                        if app.sensor != nil && (app.sensor.state != .unknown || app.sensor.serial != "") {
                            VStack(spacing: 0) {
                                Text(app.sensor.state.description)
                                    .foregroundColor(app.sensor.state == .ready ? .green : .red)

                                if app.sensor.age > 0 {
                                    Text("\(Double(app.sensor.age)/60/24, specifier: "%.1f") days")
                                }
                            }
                        }

                        if app.device != nil {
                            VStack(spacing: 0) {
                                if app.device.battery > -1 {
                                    Text("Battery: ").foregroundColor(Color(UIColor.lightGray)) +
                                        Text("\(app.device.battery)%").foregroundColor(app.device.battery > 10 ? .green : .red)
                                }
                                if app.device.rssi != 0  {
                                    Text("RSSI: ").foregroundColor(Color(UIColor.lightGray)) +
                                        Text("\(app.device.rssi) dB")
                                }
                            }
                        }

                    }.font(.footnote).foregroundColor(.yellow)

                    Text(app.info.replacingOccurrences(of: "\n", with: " "))
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity)

                    if app.info.hasPrefix("Scanning") {
                        Button(action: {
                            self.app.main.centralManager.stopScan()
                            self.app.main.info("\n\nStopped scanning")
                        }) { Image(systemName: "stop.circle").resizable().frame(width: 32, height: 32)
                        }.foregroundColor(.red)

                    }
                }

            }

            //                if history.calibratedValues.count > 0 {
            //                    VStack(spacing: 6) {
            //                        HStack {
            //                            VStack(spacing: 0) {
            //                                HStack {
            //                                    Text("Slope slope:")
            //                                    TextField("Slope slope", value: $app.calibration.slopeSlope, formatter: settings.numberFormatter,
            //                                              onEditingChanged: { changed in
            //                                                self.app.main.applyCalibration(sensor: self.app.sensor)
            //                                    }).foregroundColor(.purple)
            //                                        .onTapGesture {
            //                                            withAnimation {
            //                                                self.editingCalibration = true
            //                                            }
            //                                    }
            //                                }
            //                                if self.editingCalibration {
            //                                    Slider(value: $app.calibration.slopeSlope, in: 0.00001 ... 0.00002, step: 0.00000005)
            //                                        .accentColor(.purple)
            //                                }
            //                            }
            //
            //                            VStack(spacing: 0) {
            //                                HStack {
            //                                    Text("Slope offset:")
            //                                    TextField("Slope offset", value: $app.calibration.offsetSlope, formatter: settings.numberFormatter,
            //                                              onEditingChanged: { changed in
            //                                                self.app.main.applyCalibration(sensor: self.app.sensor)
            //                                    }).foregroundColor(.purple)
            //                                        .onTapGesture {
            //                                            withAnimation {
            //                                                self.editingCalibration = true
            //                                            }
            //                                    }
            //                                }
            //                                if self.editingCalibration {
            //                                    Slider(value: $app.calibration.offsetSlope, in: -0.02 ... 0.02, step: 0.0001)
            //                                        .accentColor(.purple)
            //                                }
            //                            }
            //                        }
            //
            //                        HStack {
            //                            VStack(spacing: 0) {
            //                                HStack {
            //                                    Text("Offset slope:")
            //                                    TextField("Offset slope", value: $app.calibration.slopeOffset, formatter: settings.numberFormatter,
            //                                              onEditingChanged: { changed in
            //                                                self.app.main.applyCalibration(sensor: self.app.sensor)
            //                                    }).foregroundColor(.purple)
            //                                        .onTapGesture {
            //                                            withAnimation {
            //                                                self.editingCalibration = true
            //                                            }
            //                                    }
            //                                }
            //                                if self.editingCalibration {
            //                                    Slider(value: $app.calibration.slopeOffset, in: -0.01 ... 0.01, step: 0.00005)
            //                                        .accentColor(.purple)
            //                                }
            //                            }
            //
            //                            VStack(spacing: 0) {
            //                                HStack {
            //                                    Text("Offset offset:")
            //                                    TextField("Offset offset", value: $app.calibration.offsetOffset, formatter: settings.numberFormatter,
            //                                              onEditingChanged: { changed in
            //                                                self.app.main.applyCalibration(sensor: self.app.sensor)
            //                                    }).foregroundColor(.purple)
            //                                        .onTapGesture {
            //                                            withAnimation {
            //                                                self.editingCalibration = true
            //                                            }
            //                                    }
            //                                }
            //                                if self.editingCalibration {
            //                                    Slider(value: $app.calibration.offsetOffset, in: -100 ... 100, step: 0.5)
            //                                        .accentColor(.purple)
            //                                }
            //                            }
            //                        }
            //                    }.font(.footnote)
            //                        // .keyboardType(.numbersAndPunctuation)
            //                }

            //                if app.sensor != nil && (self.editingCalibration || history.calibratedValues.count == 0) {
            //                    Spacer()
            //                    HStack(spacing: 20) {
            //                        if self.editingCalibration {
            //                            Button(action: {
            //                                withAnimation {
            //                                    self.editingCalibration = false
            //                                }
            //                                self.settings.calibration = Calibration()
            //                            }
            //                            ) { Text("Use").bold().padding(.horizontal, 4).padding(4).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)) }
            //
            //                            Button(action: {
            //                                withAnimation {
            //                                    self.editingCalibration = false
            //                                }
            //                                self.settings.calibration = self.app.calibration
            //                            }
            //                            ) { Text("Save").bold().padding(.horizontal, 4).padding(4).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)) }
            //                        }
            //
            //                        if self.settings.calibration != Calibration() {
            //                            Button(action: {
            //                                withAnimation {
            //                                    self.editingCalibration = false
            //                                }
            //                                self.app.calibration = self.settings.calibration
            //                                if self.app.currentGlucose < 0 {
            //                                    self.app.main.applyCalibration(sensor: self.app.sensor)
            //                                    if self.history.calibratedTrend.count > 0 {
            //                                        self.app.currentGlucose = -self.history.calibratedTrend[0].value
            //                                    }
            //                                }
            //                            }
            //                            ) { Text("Load").bold().padding(.horizontal, 4).padding(4).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)) }
            //                        }
            //
            //                        Button(action: {
            //                            withAnimation {
            //                                self.editingCalibration = false
            //                            }
            //                            self.app.calibration = self.settings.oopCalibration
            //                            self.settings.calibration = Calibration()
            //                            if self.app.currentGlucose < 0 {
            //                                self.app.main.applyCalibration(sensor: self.app.sensor)
            //                                if self.history.calibratedTrend.count > 0 {
            //                                    self.app.currentGlucose = -self.history.calibratedTrend[0].value
            //                                }
            //                            }
            //                        }
            //                        ) { Text("Restore OOP").bold().padding(.horizontal, 4).padding(4).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)) }
            //
            //                    }.font(.footnote).accentColor(.purple)
            //                }

            // Same as Rescan
            HStack {
                Spacer()
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
                ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 16, height: 16).foregroundColor(.blue) }
                    .frame(height: 16)
                Spacer()
                if !app.info.contains("canning") {
                    NavigationLink(destination: Details().environmentObject(app).environmentObject(history).environmentObject(settings)) {
                        Image(systemName: "info.circle").resizable().frame(width: 16, height: 16).foregroundColor(.blue)
                    }.frame(height: 16)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea([.bottom])
        .buttonStyle(PlainButtonStyle())
        .multilineTextAlignment(.center)
    }
}


struct Monitor_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            Monitor()
                .environmentObject(App.test(tab: .monitor))
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
