import SwiftUI

enum Tab: Hashable {
    case monitor
    case online
    case data
    case log
    case settings
}

struct ContentView: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var info: Info
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    var body: some View {

        TabView(selection: $app.selectedTab) {
            Monitor().environmentObject(app).environmentObject(info).environmentObject(history).environmentObject(settings)
                .tabItem {
                    Image(systemName: "gauge")
                    Text("Monitor")
            }.tag(Tab.monitor)

            OnlineView().environmentObject(app).environmentObject(info).environmentObject(history).environmentObject(settings)
                .tabItem {
                    Image(systemName: "globe")
                    Text("Online")
            }.tag(Tab.online)

            DataView().environmentObject(app).environmentObject(info).environmentObject(history).environmentObject(settings)
                .tabItem {
                    Image(systemName: "tray.full.fill")
                    Text("Data")
            }.tag(Tab.data)

            LogView().environmentObject(app).environmentObject(info).environmentObject(log).environmentObject(settings)
                .tabItem {
                    Image(systemName: "doc.plaintext")
                    Text("Log")
            }.tag(Tab.log)

            SettingsView().environmentObject(app).environmentObject(settings)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
            }.tag(Tab.settings)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var info: Info
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings


    static var previews: some View {

        Group {
            ContentView()
                .environmentObject(App.test(tab: .monitor))
                .environmentObject(Info.test)
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(App.test(tab: .online))
                .environmentObject(Info.test)
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(App.test(tab: .data))
                .environmentObject(Info.test)
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(App.test(tab: .log))
                .environmentObject(Info.test)
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(App.test(tab: .settings))
                .environmentObject(Info.test)
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
