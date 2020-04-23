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
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings

    var body: some View {
        VStack() {
            HStack {
                NavigationLink(destination: Monitor().environmentObject(app).environmentObject(log).environmentObject(history).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "gauge").resizable().frame(width: 32, height: 32)
                        Text("Monitor").foregroundColor(.blue)
                    }
                }
                NavigationLink(destination: Details().environmentObject(app).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "info.circle").resizable().frame(width: 32, height: 32)
                        Text("Details").foregroundColor(.blue)
                    }
                }
            }
            HStack {
                NavigationLink(destination: LogView().environmentObject(app).environmentObject(log).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "doc.plaintext").resizable().frame(width: 32, height: 32)
                        Text("Log").foregroundColor(.blue)
                    }
                }
                NavigationLink(destination: SettingsView().environmentObject(app).environmentObject(log).environmentObject(history).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "gear").resizable().frame(width: 32, height: 32)
                        Text("Settings").foregroundColor(.blue)
                    }
                }
            }
        }.foregroundColor(.red).padding(-4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .log))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
