import Foundation

struct NightscoutServer {
    let siteURL: String
    let token: String
}


class Nightscout {
    
    var server: NightscoutServer
    
    /// Main app delegate
    var main: MainDelegate!

    init(_ server: NightscoutServer) {
        self.server = server
    }
    
    func requestValues(handler: @escaping (Data?, URLResponse?, Error?, [Glucose]) -> Void) {
        var request = URLRequest(url: URL(string: "https://\(server.siteURL)/api/v1/entries/sgv.json?token=\(server.token)")!)
        main?.log("Nightscout: URL request: \(request.url!.absoluteString)")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        URLSession.shared.dataTask(with: request) { data, response, error in
            if self.main.settings.debugLevel > 0 { if let data = data { self.main?.log("Nightscout: response data: \(data.string)") } }
            if let jsondata = data {
                if let json = try? JSONSerialization.jsonObject(with: jsondata) {
                    if let array = json as? [Any] {
                        var values = [Glucose]()
                        for item in array {
                            if let dict = item as? [String: Any] {
                                if let value = dict["sgv"] as? Int, let id = dict["date"] as? Int, let device = dict["device"] as? String {
                                    values.append(Glucose(value, id: id, source: device))
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            handler(data, response, error, values)
                        }
                    }
                }
            }
        }.resume()
    }

    
    func read(handler: (([Glucose]) -> ())? = nil) {
        requestValues { data, response, error, values in
            if values.count > 0 {
                DispatchQueue.main.async {
                    self.main.history.nightscoutValues = values
                    self.main.log("Nightscout: last values: \(self.main.history.nightscoutValues.map{String($0.value)})")
                    handler?(values)
                }
            }
        }
    }
}
