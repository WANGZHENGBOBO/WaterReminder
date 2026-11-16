import Foundation
import Network

public struct LanHTTPRequest: Equatable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public enum LanHTTPParseResult: Equatable {
    case request(LanHTTPRequest)
    case incomplete
    case invalid
}

public enum LanHTTPRequestParser {
    public static let maximumHeaderBytes = 8 * 1024
    public static let maximumBodyBytes = 8 * 1024

    public static func parse(_ data: Data) -> LanHTTPParseResult {
        guard data.count <= maximumHeaderBytes + maximumBodyBytes else { return .invalid }
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)) else {
            return data.count > maximumHeaderBytes ? .invalid : .incomplete
        }
        guard boundary.lowerBound <= maximumHeaderBytes,
              let headerText = String(data: data[..<boundary.lowerBound], encoding: .utf8) else {
            return .invalid
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .invalid }
        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count == 3, requestParts[2].hasPrefix("HTTP/") else { return .invalid }
        let method = String(requestParts[0]).uppercased()

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return .invalid }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return .invalid }
            headers[name] = value
        }
        let contentLength: Int
        if let contentLengthText = headers["content-length"] {
            guard let parsedLength = Int(contentLengthText),
                  parsedLength >= 0, parsedLength <= maximumBodyBytes else {
                return .invalid
            }
            contentLength = parsedLength
        } else if method == "GET" || method == "HEAD" {
            contentLength = 0
        } else {
            return .invalid
        }

        let bodyStart = boundary.upperBound
        let availableBodyBytes = data.count - bodyStart
        guard availableBodyBytes >= contentLength else { return .incomplete }
        guard availableBodyBytes == contentLength else { return .invalid }

        return .request(LanHTTPRequest(
            method: method,
            path: String(requestParts[1]),
            headers: headers,
            body: data[bodyStart...]
        ))
    }
}

public enum LanDrinkResponse: Equatable, Sendable {
    case accepted(duplicate: Bool)
    case today(DrinkSyncTodaySummary)
    case unauthorized
    case invalid(String)
    case unavailable(String)
}

public final class LanDrinkServer: @unchecked Sendable {
    public typealias Handler = @Sendable (DrinkSyncEvent) async -> LanDrinkResponse
    public typealias TodayHandler = @Sendable () async -> LanDrinkResponse

    private let token: String
    private let handler: Handler
    private let todayHandler: TodayHandler?
    private let queue = DispatchQueue(label: "com.bobo.WaterReminder.lan-sync")
    private var listener: NWListener?

    public init(token: String, handler: @escaping Handler,
                todayHandler: TodayHandler? = nil) {
        self.token = token
        self.handler = handler
        self.todayHandler = todayHandler
    }

    deinit {
        stop()
    }

    @discardableResult
    public func start(preferredPort: UInt16 = 47832) throws -> UInt16 {
        stop()
        let candidatePorts: [UInt16] = preferredPort == 0
            ? [0]
            : (0..<8).map { UInt16(Int(preferredPort) + $0) }
        for portValue in candidatePorts {
            guard let port = NWEndpoint.Port(rawValue: portValue) else { continue }
            if let actual = try listen(on: port) {
                return actual
            }
        }
        throw CocoaError(.fileWriteUnknown)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func listen(on port: NWEndpoint.Port) throws -> UInt16? {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: port)
        let ready = DispatchSemaphore(value: 0)
        var didBecomeReady = false
        var failed = false
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                didBecomeReady = true
                ready.signal()
            case .failed:
                failed = true
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        if ready.wait(timeout: .now() + 2) == .timedOut {
            listener.cancel()
            return nil
        }
        guard didBecomeReady, !failed, let actualPort = listener.port?.rawValue else {
            listener.cancel()
            return nil
        }
        self.listener = listener
        return actualPort
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }

    private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }
            if buffer.count > LanHTTPRequestParser.maximumHeaderBytes
                + LanHTTPRequestParser.maximumBodyBytes {
                self.respond(.invalid("request too large"), on: connection)
                return
            }
            switch LanHTTPRequestParser.parse(buffer) {
            case .request(let request):
                self.handle(request, on: connection)
            case .incomplete:
                if isComplete || error != nil {
                    connection.cancel()
                } else {
                    self.receive(on: connection, accumulated: buffer)
                }
            case .invalid:
                self.respond(.invalid("bad request"), on: connection)
            }
        }
    }

    private func handle(_ request: LanHTTPRequest, on connection: NWConnection) {
        if request.method == "GET" && request.path == "/v1/today" {
            guard request.headers["authorization"] == "Bearer \(token)" else {
                respond(.unauthorized, on: connection)
                return
            }
            guard let todayHandler else {
                respond(.invalid("not found"), on: connection, status: 404)
                return
            }
            Task { [todayHandler] in
                let result = await todayHandler()
                self.respond(result, on: connection)
            }
            return
        }
        guard request.method == "POST", request.path == "/v1/drink" else {
            respond(.invalid("not found"), on: connection, status: 404)
            return
        }
        guard request.headers["authorization"] == "Bearer \(token)" else {
            respond(.unauthorized, on: connection)
            return
        }
        guard let event = try? DrinkSyncEvent.decode(request.body) else {
            respond(.invalid("invalid event"), on: connection)
            return
        }
        Task { [handler] in
            let result = await handler(event)
            self.respond(result, on: connection)
        }
    }

    private func respond(_ result: LanDrinkResponse, on connection: NWConnection,
                         status overrideStatus: Int? = nil) {
        let status: Int
        let bodyData: Data
        switch result {
        case .accepted(let duplicate):
            status = overrideStatus ?? 200
            bodyData = Data(#"{"ok":true,"duplicate":\#(duplicate)}"#.utf8)
        case .today(let summary):
            status = overrideStatus ?? 200
            bodyData = (try? JSONEncoder().encode(summary))
                ?? Data(#"{"ok":false,"error":"could not encode summary"}"#.utf8)
        case .unauthorized:
            status = overrideStatus ?? 401
            bodyData = Data(#"{"ok":false,"error":"unauthorized"}"#.utf8)
        case .invalid(let message):
            status = overrideStatus ?? 400
            bodyData = Data(#"{"ok":false,"error":"\#(escape(message))"}"#.utf8)
        case .unavailable(let message):
            status = overrideStatus ?? 503
            bodyData = Data(#"{"ok":false,"error":"\#(escape(message))"}"#.utf8)
        }
        let head = "HTTP/1.1 \(status) \(reason(status))\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(bodyData.count)\r\n"
            + "Connection: close\r\n\r\n"
        var response = Data(head.utf8)
        response.append(bodyData)
        connection.send(content: response, contentContext: .finalMessage, isComplete: true,
                        completion: .contentProcessed { _ in connection.cancel() })
    }

    private func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        case 503: "Service Unavailable"
        default: "Error"
        }
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
