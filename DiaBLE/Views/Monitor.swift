import Foundation
import SwiftUI


struct Monitor: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    @State private var showingNFCAlert = false
    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {

            VStack {
                Spacer()
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
                        Text(app.transmitterState)
                            .foregroundColor(app.transmitterState == "Connected" ? .green : .red)
                            .fixedSize()

                        if app.transmitterState == "Connected" {

                            Text(readingCountdown > 0 || app.info.hasSuffix("sensor") ?
                                "\(readingCountdown) s" : "")
                                .fixedSize()
                                .onReceive(timer) { _ in
                                    self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                            }.font(Font.callout.monospacedDigit()).foregroundColor(.orange)
                        }
                    }
                }


                Graph().environmentObject(history).environmentObject(settings).frame(width: 31 * 7 + 60, height: 150)


                HStack(spacing: 12) {

                    if app.sensor != nil && app.sensor.state != .unknown {
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

                    if app.transmitter != nil {
                        VStack {
                            if app.transmitter.battery > -1 {
                                Text("Battery: \(app.transmitter.battery)%")
                            }
                            if app.transmitter.firmware.count > 0 {
                                Text("Firmware: \(app.transmitter.firmware)")
                            }
                            if app.transmitter.hardware.count > 0  {
                                Text("Hardware: \(app.transmitter.hardware)")
                            }
                            if app.transmitter.macAddress.count > 0  {
                                Text("\(app.transmitter.macAddress.hexAddress)")
                            }
                        }
                    }

                }.font(.footnote).foregroundColor(.yellow)

                VStack {
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

                    NavigationLink(destination: Details(device: app.transmitter)) {
                        Text(" Device... ").font(.footnote).bold().padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2))
                    }.disabled(self.app.transmitter == nil && self.settings.preferredWatch == .none)
                }

                Spacer()

                if app.calibration.offsetOffset != 0.0 {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Slope slope:")
                            TextField("Slope slope", value: $app.calibration.slopeSlope, formatter: settings.numberFormatter)
                                .foregroundColor(.purple)
                            Text("Slope offset:")
                            TextField("Slope offset", value: $app.calibration.offsetSlope, formatter: settings.numberFormatter)
                                .foregroundColor(.purple)
                        }
                        HStack {
                            Text("Offset slope:")
                            TextField("Offset slope", value: $app.calibration.slopeOffset, formatter: settings.numberFormatter)
                                .foregroundColor(.purple)
                            Text("Offset offset:")
                            TextField("Offset offset", value: $app.calibration.offsetOffset, formatter: settings.numberFormatter)
                                .foregroundColor(.purple)
                        }
                    }
                    .font(.footnote)
                    .keyboardType(.numbersAndPunctuation)
                }

                Spacer()

                // Same as Rescan
                Button(action: {
                    let transmitter = self.app.transmitter
                    let centralManager = self.app.main.centralManager
                    if transmitter != nil {
                        centralManager.cancelPeripheralConnection(transmitter!.peripheral!)
                    }
                    if centralManager.state == .poweredOn {
                        centralManager.scanForPeripherals(withServices: nil, options: nil)
                        self.app.main.info("\n\nScanning...")
                    }
                    if let healthKit = self.app.main.healthKit { healthKit.read() }
                    if let nightscout = self.app.main.nightscout { nightscout.read() }
                }
                ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 32, height: 32).padding(.bottom, 8
                ).foregroundColor(.accentColor) }

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
                }) { VStack {
                    Image(systemName: "radiowaves.left")
                        .resizable().rotationEffect(.degrees(90)).frame(width: 16, height: 32).offset(y: 8)
                    Text("NFC").font(.footnote).bold().offset(y: -8)
                    Text("  Scan  ").font(.footnote).offset(y: -12)
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
