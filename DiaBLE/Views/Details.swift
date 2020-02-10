import Foundation
import SwiftUI

struct Details: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    
    var device: Device?
    
    var body: some View {
        VStack {
            Spacer()

            Text("TODO: \(device?.name ?? "Details")")

            Spacer()

            if device?.name == Watlaa.name {
                WatlaaDetailsView(device: device!)
            }

            Spacer()
        }
        .navigationBarTitle(Text("Details"), displayMode: .inline)
    }
}

struct Details_Preview: PreviewProvider {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(App.test(tab: .settings))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
