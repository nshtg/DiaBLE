import Foundation
import SwiftUI


struct Monitor: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var log: Log
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

                        Text(app.lastReadingDate.shortTime)
                        Text("\(Int(Date().timeIntervalSince(app.lastReadingDate)/60)) min ago").font(.system(size: 10)).lineLimit(1)

                    }.font(.footnote).frame(maxWidth: .infinity, alignment: .trailing ).foregroundColor(Color(UIColor.lightGray))

                    // currentGlucose is negative when set to the last trend raw value (no online connection or calibration)
                    Text(app.currentGlucose > 0 ? "\(app.currentGlucose)" : (app.currentGlucose < 0 ? "(\(-app.currentGlucose))" : "---"))
                        .fontWeight(.black)
                        .foregroundColor(.black)
                        .padding(.vertical, 10).padding(.horizontal, app.currentGlucose > 0 ? 10 : 4)
                        .background(abs(app.currentGlucose) > 0 && (abs(app.currentGlucose) > Int(settings.alarmHigh) || abs(app.currentGlucose) < Int(settings.alarmLow)) ? Color.red :
                                        (app.currentGlucose < 0 ?
                                            (history.calibratedTrend.count > 0 ? Color.purple : Color.yellow) : Color.blue))
                        .cornerRadius(5)


                    Text(OOP.TrendArrow(rawValue: app.oopTrend)?.symbol ?? "---").font(.system(size: 28)).bold().foregroundColor(.blue).bold().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10).padding(.bottom, -18)
                }

                Text("\(app.oopAlarm.replacingOccurrences(of: "_", with: " ")) - \(app.oopTrend.replacingOccurrences(of: "_", with: " "))")
                    .font(.footnote).foregroundColor(.blue).lineLimit(1)

                HStack {
                    Text(app.deviceState)
                        .foregroundColor(app.deviceState == "Connected" ? .green : .red)
                        .font(.footnote).fixedSize()

                    if app.deviceState == "Connected" {

                        Text(readingCountdown > 0 || app.status.hasSuffix("sensor") ?
                                "\(readingCountdown) s" : "")
                            .fixedSize()
                            .onReceive(timer) { _ in
                                self.readingCountdown = self.settings.readingInterval * 60 - Int(Date().timeIntervalSince(self.app.lastReadingDate))
                            }
                            .font(Font.footnote.monospacedDigit()).foregroundColor(.orange)
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
                                    .foregroundColor(app.sensor.state == .active ? .green : .red)

                                if app.sensor.age > 0 {
                                    Text(app.sensor.age.shortFormattedInterval)
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

                    Text(app.status.replacingOccurrences(of: "\n", with: " "))
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity)

                }

            }

            Spacer()
            
            HStack {
                Spacer()

                NavigationLink(destination: ContentView().environmentObject(app).environmentObject(history).environmentObject(log).environmentObject(settings)) {
                    Image(systemName: "chevron.left.circle.fill").resizable().frame(width: 16, height: 16).foregroundColor(.blue)
                }.frame(height: 16)

                Spacer()

                Button(action: {
                    let device = self.app.device
                    let centralManager = self.app.main.centralManager
                    if device != nil {
                        centralManager.cancelPeripheralConnection(device!.peripheral!)
                    }
                    if centralManager.state == .poweredOn {
                        centralManager.scanForPeripherals(withServices: nil, options: nil)
                        self.app.main.status("Scanning...")
                    }
                    if let healthKit = self.app.main.healthKit { healthKit.read() }
                    if let nightscout = self.app.main.nightscout { nightscout.read() }
                }
                ) { Image(systemName: "arrow.clockwise.circle").resizable().frame(width: 16, height: 16).foregroundColor(.blue) }
                .frame(height: 16)

                if app.status.hasPrefix("Scanning") || app.status.hasSuffix("retrying...") {
                    Spacer()
                    Button(action: {
                        self.app.main.centralManager.stopScan()
                        self.app.main.status("Stopped scanning")
                        self.app.main.log("Bluetooth: stopped scanning")
                    }) { Image(systemName: "stop.circle").resizable().frame(width: 16, height: 16).foregroundColor(.red) }
                    .frame(height: 16)
                }

                Spacer()

                NavigationLink(destination: Details().environmentObject(app).environmentObject(history).environmentObject(settings)) {
                    Image(systemName: "info.circle").resizable().frame(width: 16, height: 16).foregroundColor(.blue)
                }.frame(height: 16)
                Spacer()
            }
        }
        // .navigationTitle("Monitor")
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea([.bottom])
        .buttonStyle(PlainButtonStyle())
        .multilineTextAlignment(.center)
    }
}


struct Monitor_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            Monitor()
                .environmentObject(AppState.test(tab: .monitor))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
        }
    }
}
