import Foundation
import SwiftUI


struct SettingsView: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var settings: Settings

    @State private var showingCalendarPicker = false


    var body: some View {

        VStack {

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        //                        Button(action: {} ) { Image("Bluetooth").resizable().frame(width: 32, height: 32) }
                        Picker(selection: $settings.preferredTransmitter, label: Text("Preferred")) {
                            ForEach(TransmitterType.allCases) { t in
                                Text(t.name).tag(t)
                            }
                        } // .pickerStyle(SegmentedPickerStyle())

                        //                        Button(action: {} ) { Image(systemName: "line.horizontal.3.decrease.circle").resizable().frame(width: 20, height: 20)// .padding(.leading, 6)
                        //                        }
                        TextField("device name pattern", text: $settings.preferredDevicePattern)
                            // .padding(.horizontal, 12)
                            .frame(alignment: .center)
                    }
                }.frame(height: 34).font(.footnote).foregroundColor(.blue)

                //                    HStack  {
                //                        Image(systemName: "clock.fill").resizable().frame(width: 18, height: 18).padding(.leading, 7).foregroundColor(.white)
                //                        Picker(selection: $settings.preferredWatch, label: Text("Preferred")) {
                //                            ForEach(WatchType.allCases) { t in
                //                                Text(t.name).tag(t)
                //                            }
                //                        } // .pickerStyle(SegmentedPickerStyle())
                //                    }

                //                    NavigationLink(destination: Details().environmentObject(app).environmentObject(settings)) {
                //                        Text("Details").font(.footnote).bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2))
                //                    }
            }

            VStack {
                VStack(spacing: 0) {
                    Image(systemName: "hand.thumbsup.fill").foregroundColor(.green)
                    Text("\(Int(settings.targetLow), specifier: "%3lld") - \(Int(settings.targetHigh))").foregroundColor(.green)
                    HStack {
                        Slider(value: $settings.targetLow,  in: 40 ... 99, step: 1).frame(height: 20).scaleEffect(0.6)
                        Slider(value: $settings.targetHigh, in: 140 ... 299, step: 1).frame(height: 20).scaleEffect(0.6)
                    }
                }.accentColor(.green)

                VStack(spacing: 0) {
                    Image(systemName: "bell.fill").foregroundColor(.red)
                    Text("<\(Int(settings.alarmLow), specifier: "%3lld")   > \(Int(settings.alarmHigh))").foregroundColor(.red)
                    HStack {
                        Slider(value: $settings.alarmLow,  in: 40 ... 99, step: 1).frame(height: 20).scaleEffect(0.6)
                        Slider(value: $settings.alarmHigh, in: 140 ... 299, step: 1).frame(height: 20).scaleEffect(0.6)
                    }
                }.accentColor(.red)
            }

            HStack() {

                Spacer()

                HStack(spacing: 3) {
                    Button(action: {
                        let device = self.app.device
                        // TODO: switch to Monitor
                        // self.app.selectedTab = (self.settings.preferredTransmitter != .none || self.settings.preferredWatch != .none) ? .monitor : .log
                        let centralManager = self.app.main.centralManager
                        if device != nil {
                            centralManager.cancelPeripheralConnection(device!.peripheral!)
                        }
                        if centralManager.state == .poweredOn {
                            centralManager.scanForPeripherals(withServices: nil, options: nil)
                            self.app.main.info("\n\nScanning...")
                        }
                        if let healthKit = self.app.main.healthKit { healthKit.read() }
                        // if let nightscout = self.app.main.nightscout { nightscout.read() }
                    }
                    ) { Image(systemName: "timer").resizable().frame(width: 20, height: 20) }

                    Picker(selection: $settings.readingInterval, label: Text("")) {
                        ForEach(Array(stride(from: 1,
                                             through: settings.preferredTransmitter == .miaomiao || (settings.preferredTransmitter == .none && app.transmitter != nil && app.transmitter.type == .transmitter(.miaomiao)) ? 5 : 15,
                                             by: settings.preferredTransmitter == .miaomiao || (settings.preferredTransmitter == .none && app.transmitter != nil && app.transmitter.type == .transmitter(.miaomiao)) ? 2 : 1)),
                                id: \.self) { t in
                                    Text("\(t) min")
                        }
                    }.labelsHidden().frame(width: 60, height: 36).padding(.top, -16)
                }.font(.footnote).foregroundColor(.orange)

                Spacer()

                Button(action: {
                    self.settings.mutedAudio.toggle()
                }) {
                    Image(systemName: settings.mutedAudio ? "speaker.slash.fill" : "speaker.2.fill").resizable().frame(width: 20, height: 20).foregroundColor(.blue)
                }

                Spacer()

                Button(action: {
                    self.settings.disabledNotifications.toggle()
                    if self.settings.disabledNotifications {
                        // UIApplication.shared.applicationIconBadgeNumber = 0
                    } else {
                        // UIApplication.shared.applicationIconBadgeNumber = self.app.currentGlucose
                    }
                }) {
                    Image(systemName: settings.disabledNotifications ? "zzz" : "app.badge.fill").resizable().frame(width: 20, height: 20).foregroundColor(.blue)
                }

                //                    Button(action: {
                //                        self.showingCalendarPicker = true
                //                    }) {
                //                        Image(systemName: settings.calendarTitle != "" ? "calendar.circle.fill" : "calendar.circle").resizable().frame(width: 32, height: 32).foregroundColor(.accentColor)
                //                    }
                //                    .popover(isPresented: $showingCalendarPicker, arrowEdge: .bottom) {
                //                        VStack {
                //                            Section {
                //                                Button(action: {
                //                                    self.settings.calendarTitle = ""
                //                                    self.showingCalendarPicker = false
                //                                    self.app.main.eventKit?.sync()
                //                                }
                //                                ) { Text("None").bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)) }
                //                                    .disabled(self.settings.calendarTitle == "")
                //                            }
                //                            Section {
                //                                Picker(selection: self.$settings.calendarTitle, label: Text("Calendar")) {
                //                                    ForEach([""] + (self.app.main.eventKit?.calendarTitles ?? [""]), id: \.self) { title in
                //                                        Text(title != "" ? title : "None")
                //                                    }
                //                                }
                //                            }
                //                            Section {
                //                                HStack {
                //                                    Image(systemName: "bell.fill").foregroundColor(.red).padding(8)
                //                                    Toggle("High / Low", isOn: self.$settings.calendarAlarmIsOn)
                //                                        .disabled(self.settings.calendarTitle == "")
                //                                }
                //                            }
                //                            Section {
                //                                Button(action: {
                //                                    self.showingCalendarPicker = false
                //                                    self.app.main.eventKit?.sync()
                //                                }
                //                                ) { Text(self.settings.calendarTitle == "" ? "Don't remind" : "Remind").bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)).animation(.default) }
                //
                //                            }.padding(.top, 40)
                //                        }.padding(60)
                //                    }

                Spacer()
            }.padding(.top, 10)

        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle(Text("Settings"))
        .font(Font.body.monospacedDigit())
        .buttonStyle(PlainButtonStyle())
    }
}


struct SettingsView_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            SettingsView()
                .environmentObject(App.test(tab: .settings))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
