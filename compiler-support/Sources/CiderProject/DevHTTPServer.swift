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

    /// Largest request body the console will assemble. An edit request is a few
    /// hundred bytes; anything approaching this is a bug or an attack, and
    /// reading it would let one connection hold the single-threaded accept loop.
    public static let maximumBodyBytes = 1 << 20

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
        // Read the head first, then exactly as much body as Content-Length
        // says. A single read() was enough for a GET and silently wrong for
        // anything else: a browser routinely writes headers and body in
        // separate segments, so a POST could arrive with its body truncated to
        // nothing and no error anywhere.
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 16384)

        func readMore() -> Bool {
            let count = Glibc.read(client, &chunk, chunk.count)
            guard count > 0 else { return false }
            data.append(contentsOf: chunk.prefix(Int(count)))
            return true
        }

        // Rescan only the new bytes, less the three that could hold a
        // terminator split across two reads.
        var scanned = 0
        var bodyStart = Self.headerEnd(in: data, from: scanned)
        while bodyStart == nil {
            guard data.count <= Self.maximumBodyBytes else {
                write(response: Self.tooLarge, to: client)
                return
            }
            scanned = max(0, data.count - 3)
            guard readMore() else { return }
            bodyStart = Self.headerEnd(in: data, from: scanned)
        }

        guard let start = bodyStart, var request = parse(data, bodyStart: start) else {
            write(response: DevDashboardResponse(status: 400, contentType: "text/plain", body: Data("bad request".utf8)), to: client)
            return
        }

        let declared = Int(request.headers["content-length"] ?? "") ?? 0
        guard declared <= Self.maximumBodyBytes else {
            write(response: Self.tooLarge, to: client)
            return
        }
        while data.count - start < declared {
            guard readMore() else { break }
        }
        request.body = Data(data.dropFirst(start).prefix(declared))

        write(response: handler(request), to: client)
        #endif
    }

    private static let tooLarge = DevDashboardResponse(
        status: 413,
        contentType: "text/plain",
        body: Data("CID0630: request body exceeds \(maximumBodyBytes) bytes".utf8)
    )

    /// Byte offset just past the `\r\n\r\n` that ends the request head, or nil
    /// while the head is still incomplete. Searched over bytes rather than a
    /// decoded String, because the body may not be valid UTF-8 and decoding the
    /// whole buffer to find the head would fail on a binary upload.
    private static func headerEnd(in data: Data, from offset: Int = 0) -> Int? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, offset <= bytes.count - 4 else { return nil }
        for index in offset...(bytes.count - 4)
        where bytes[index] == 0x0D && bytes[index + 1] == 0x0A && bytes[index + 2] == 0x0D && bytes[index + 3] == 0x0A {
            return index + 4
        }
        return nil
    }

    private func parse(_ data: Data, bodyStart: Int) -> DevHTTPRequest? {
        let terminator = 4
        guard bodyStart >= terminator,
              let headerText = String(data: data.prefix(bodyStart - terminator), encoding: .utf8) else { return nil }
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
        // The body is filled in by `handle`, which knows how much to wait for.
        return DevHTTPRequest(method: parts[0], path: path, query: query, headers: headers, body: Data())
    }

    private static func reason(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 409: return "Conflict"
        case 413: return "Payload Too Large"
        default: return "Error"
        }
    }

    private func write(response: DevDashboardResponse, to client: Int32) {
        #if canImport(Glibc)
        var header = "HTTP/1.1 \(response.status) \(Self.reason(for: response.status))\r\n"
        header += "Content-Type: \(response.contentType)\r\n"
        header += "Content-Length: \(response.body.count)\r\n"
        header += "Access-Control-Allow-Origin: http://127.0.0.1:\(port)\r\n"
        for (name, value) in response.headers.sorted(by: { $0.key < $1.key }) {
            header += "\(name): \(value)\r\n"
        }
        header += "Connection: close\r\n\r\n"
        var bytes = Array(header.utf8) + Array(response.body)
        let byteCount = bytes.count
        bytes.withUnsafeMutableBytes { raw in _ = Glibc.write(client, raw.baseAddress, byteCount) }
        #endif
    }
}
