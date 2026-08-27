import CiderUI

@main
struct RESTClientCiderApp: CiderApp {
    @CiderState private var endpoint = "https://example.com"
    @CiderState private var status = "Ready"
    @CiderState private var responseBody = ""

    var body: some CiderView {
        VStack(spacing: 18) {
            Text("REST Client").font(size: 28, weight: .bold)
            TextField($endpoint, width: 300)
            Button("GET") { fetch() }
            Button("Copy Body") { CiderClipboard.copy(responseBody) }
            Text(status).font(size: 14)
            ScrollView(width: 300, height: 260) {
                Text(responseBody.isEmpty ? "No response yet" : responseBody).font(size: 12)
            }
        }
    }

    private func fetch() {
        status = "Requesting..."
        do {
            let response = try CiderHTTP.getBlocking(endpoint)
            responseBody = response.body
            status = response.statusCode == 0 ? "Received" : "HTTP \(response.statusCode)"
            try? CiderStorage.cache.writeText(response.body, named: "last-response.txt")
        } catch {
            status = "Request failed"
        }
    }
}
