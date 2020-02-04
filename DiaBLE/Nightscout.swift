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

    // TODO: query parameters
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
                                    values.append(Glucose(value, id: id, date: Date(timeIntervalSince1970: Double(id)/1000), source: device))
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
                    if self.main.settings.debugLevel > 0 { self.main.log("Nightscout: last values: \(self.main.history.nightscoutValues.map{String($0.value)})") }
                    handler?(values)
                }
            }
        }
    }


    // TODO:
    func post(_ glucose: Glucose, handler: (((Data?, URLResponse?, Error?) -> Void))? = nil) {

        let dict: [String: Any] = [
            "type": "sgv",
            "sgv": glucose.value,
            "device": "DiaBLE", // TODO
            "date": Int64((glucose.date.timeIntervalSince1970 * 1000.0).rounded()),
            // "direction": "NOT COMPUTABLE", // TODO
        ]

        let json = try! JSONSerialization.data(withJSONObject: dict, options: [])
        var request = URLRequest(url: URL(string: "https://\(server.siteURL)/api/v1/entries?token=\(server.token)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        request.setValue(server.token.sha1,  forHTTPHeaderField:"api-secret")
        URLSession.shared.uploadTask(with: request, from: json) { data, response, error in
            if let error = error {
                self.main?.log("Nightscout: error: \(error.localizedDescription)")
            } else {
                if let response = response as? HTTPURLResponse {
                    let status = response.statusCode
                    if self.main.settings.debugLevel > 0 {
                        if let data = data {
                            self.main?.log("Nightscout: post \((200..<300).contains(status) ? "success" : "error") (\(status)): \(data.string)")

                        }
                    }
                }
            }
            DispatchQueue.main.async {
                handler?(data, response, error)
            }
        }.resume()
    }


    // TODO:
    func test(_ handler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: "https://\(server.siteURL)/api/v1/entries/sgv.json?token=\(server.token)")!)
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        request.setValue(server.token.sha1, forHTTPHeaderField:"api-secret")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                handler(data, response, error)
            }
        }.resume()
    }
}
