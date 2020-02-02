import Foundation
import SwiftUI
import WebKit


struct WebView: UIViewRepresentable {

    let site: String
    var endpoint: String = ""
    var query: String = ""

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView(frame: .zero)
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        var url = "https://" + site
        if !endpoint.isEmpty {
            url += ("/" + endpoint)
        }
        if !query.isEmpty {
            url += ("?" + query)
        }
        if let url = URL(string: url) {
            view.load(URLRequest(url: url))
        }
    }
}
