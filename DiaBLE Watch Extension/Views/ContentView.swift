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
        VStack {
            NavigationLink(destination: Monitor().environmentObject(app).environmentObject(history).environmentObject(log).environmentObject(settings)) {
                Text("Monitor")
            }
            NavigationLink(destination: LogView().environmentObject(app).environmentObject(log).environmentObject(settings)) {
                Text("Log")
            }
        }
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
