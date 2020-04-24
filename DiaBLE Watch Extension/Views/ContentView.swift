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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                NavigationLink(destination: Monitor().environmentObject(app).environmentObject(log).environmentObject(history).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "gauge").resizable().frame(width: 32, height: 32).offset(y: 4)
                        Text("Monitor").foregroundColor(.blue)
                    }.frame(maxWidth: .infinity).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 1.5))
                }
                NavigationLink(destination: Details().environmentObject(app).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "info.circle").resizable().frame(width: 32, height: 32).offset(y: 4)
                        Text("Details").foregroundColor(.blue)
                    }.frame(maxWidth: .infinity).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 1.5))
                }
            }
            HStack(spacing: 10) {
                NavigationLink(destination: LogView().environmentObject(app).environmentObject(log).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "doc.plaintext").resizable().frame(width: 32, height: 32).offset(y: 4)
                        Text("Log").foregroundColor(.blue)
                    }.frame(maxWidth: .infinity).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 1.5))
                }
                NavigationLink(destination: SettingsView().environmentObject(app).environmentObject(log).environmentObject(history).environmentObject(settings)) {
                    VStack {
                        Image(systemName: "gear").resizable().frame(width: 32, height: 32).offset(y: 4)
                        Text("Settings").tracking(-0.5).foregroundColor(.blue)
                    }.frame(maxWidth: .infinity).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 1.5))
                }
            }
        }.padding(4)
            .foregroundColor(.red)
            .buttonStyle(PlainButtonStyle())
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
