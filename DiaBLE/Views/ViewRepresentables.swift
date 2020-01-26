import Foundation
import SwiftUI
import WebKit


struct WebView: UIViewRepresentable {

    let site: String

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView(frame: .zero)
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if let url = URL(string: "https://" + site) {
            let request = URLRequest(url: url)
            view.load(request)
        }
    }
}
