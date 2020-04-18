import WatchKit
import Foundation
import SwiftUI

class HostingController: WKHostingController<AnyView> {
    override var body: AnyView {
        let mainDelegate = MainDelegate()
        mainDelegate.app.main = mainDelegate
        let contentView = AnyView(ContentView()
            .environmentObject(mainDelegate.app)
            .environmentObject(mainDelegate.log)
            .environmentObject(mainDelegate.history)
            .environmentObject(mainDelegate.settings))
        return contentView
    }
}
