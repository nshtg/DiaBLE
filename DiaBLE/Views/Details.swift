import Foundation
import SwiftUI

struct Details: View {
    @EnvironmentObject var app: App
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    
    var transmitter: Transmitter?
    
    var body: some View {
        VStack {
            Text("TODO: \(transmitter?.name ?? "Details")")
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
