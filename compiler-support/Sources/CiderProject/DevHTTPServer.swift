//  Tiny loopback-only HTTP/1.1 server for `cider dev`.

import Foundation
#if canImport(Glibc)
import Glibc
#endif

public struct DevHTTPRequest: Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]
    public var headers: [String: String]
    public var body: Data
}

public final class DevHTTPServer: @unchecked Sendable {
    private let port: Int
    private let handler: @Sendable (DevHTTPRequest) -> DevDashboardResponse
    private var socketFD: Int32 = -1
    private var running = false
    private let queue = DispatchQueue(label: "dev-http-server")

    public init(port: Int, handler: @escaping @Sendable (DevHTTPRequest) -> DevDashboardResponse) {
        self.port = port
        self.handler = handler
    }

    public var boundURL: String { "http://127.0.0.1:\(port)/" }

    public func start() throws {
        #if canImport(Glibc)
        socketFD = Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        guard socketFD >= 0 else { throw NSError(domain: "DevHTTPServer", code: 1) }
        var yes: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Glibc.bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { Glibc.close(socketFD); throw NSError(domain: "DevHTTPServer", code: 2) }
        guard Glibc.listen(socketFD, 16) == 0 else { Glibc.close(socketFD); throw NSError(domain: "DevHTTPServer", code: 3) }
        running = true
        queue.async { [self] in acceptLoop() }
        #else
        throw NSError(domain: "DevHTTPServer", code: 4)
        #endif
    }

    public func stop() {
        running = false
        #if canImport(Glibc)
        if socketFD >= 0 { Glibc.close(socketFD); socketFD = -1 }
        #endif
    }

    private func acceptLoop() {
        #if canImport(Glibc)
        while running {
            let client = Glibc.accept(socketFD, nil, nil)
            if client < 0 { continue }
            handle(client: client)
            Glibc.close(client)
        }
        #endif
    }

    private func handle(client: Int32) {
        #if canImport(Glibc)
        var buffer = [UInt8](repeating: 0, count: 65536)
        let count = Glibc.read(client, &buffer, buffer.count)
        guard count > 0 else { return }
        let data = Data(buffer.prefix(Int(count)))
        guard let request = parse(data) else {
            write(response: DevDashboardResponse(status: 400, contentType: "text/plain", body: Data("bad request".utf8)), to: client)
            return
        }
        write(response: handler(request), to: client)
        #endif
    }

    private func parse(_ data: Data) -> DevHTTPRequest? {
        guard let text = String(data: data, encoding: .utf8), let headerEnd = text.range(of: "\r\n\r\n") else { return nil }
        let headerText = String(text[..<headerEnd.lowerBound])
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        var path = parts[1]
        var query: [String: String] = [:]
        if let question = path.firstIndex(of: "?") {
            let queryText = String(path[path.index(after: question)...])
            path = String(path[..<question])
            for pair in queryText.split(separator: "&") {
                let bits = pair.split(separator: "=", maxSplits: 1).map(String.init)
                let key = bits.first?.removingPercentEncoding ?? ""
                let value = bits.count > 1 ? (bits[1].removingPercentEncoding ?? bits[1]) : ""
                query[key] = value
            }
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        let bodyStart = text.distance(from: text.startIndex, to: headerEnd.upperBound)
        let body = data.dropFirst(bodyStart)
        return DevHTTPRequest(method: parts[0], path: path, query: query, headers: headers, body: Data(body))
    }

    private func write(response: DevDashboardResponse, to client: Int32) {
        #if canImport(Glibc)
        let reason = response.status == 200 ? "OK" : response.status == 204 ? "No Content" : response.status == 404 ? "Not Found" : "Error"
        var header = "HTTP/1.1 \(response.status) \(reason)\r\n"
        header += "Content-Type: \(response.contentType)\r\n"
        header += "Content-Length: \(response.body.count)\r\n"
        header += "Access-Control-Allow-Origin: http://127.0.0.1:\(port)\r\n"
        header += "Connection: close\r\n\r\n"
        var bytes = Array(header.utf8) + Array(response.body)
        let byteCount = bytes.count
        bytes.withUnsafeMutableBytes { raw in _ = Glibc.write(client, raw.baseAddress, byteCount) }
        #endif
    }
}
