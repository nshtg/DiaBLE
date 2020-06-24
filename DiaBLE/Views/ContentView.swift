import SwiftUI

enum Tab: Hashable {
    case monitor
    case online
    case data
    case log
    case settings
}

struct ContentView: View {
    @EnvironmentObject var app: DiaBLEAppState
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    var body: some View {

        TabView(selection: $app.selectedTab) {
            Monitor()
                .tabItem {
                    Image(systemName: "gauge")
                    Text("Monitor")
            }.tag(Tab.monitor)

            OnlineView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Online")
            }.tag(Tab.online)

            DataView()
                .tabItem {
                    Image(systemName: "tray.full.fill")
                    Text("Data")
            }.tag(Tab.data)

            LogView()
                .tabItem {
                    Image(systemName: "doc.plaintext")
                    Text("Log")
            }.tag(Tab.log)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
            }.tag(Tab.settings)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    @EnvironmentObject var app: DiaBLEAppState
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings


    static var previews: some View {

        Group {
            ContentView()
                .environmentObject(DiaBLEAppState.test(tab: .monitor))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(DiaBLEAppState.test(tab: .online))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(DiaBLEAppState.test(tab: .data))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(DiaBLEAppState.test(tab: .log))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)

            ContentView()
                .environmentObject(DiaBLEAppState.test(tab: .settings))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
