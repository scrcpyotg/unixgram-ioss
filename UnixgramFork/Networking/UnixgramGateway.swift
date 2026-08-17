import Foundation

enum UnixgramDocumentedRoute {
    static let csrf = "/api/auth/csrf"
    static let realtimeSSE = "/api/realtime/events"

    // Unixgram's public API page uses /api/social/posts as an example
    // for CSRF-protected mutation, but per-method documentation is not
    // publicly published yet. Do not assume request/response schema here.
}

struct UnixgramAPIError: Decodable, Error {
    let code: String
    let message: String
    let details: [String]?
}

struct UnixgramEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: UnixgramAPIError?
}

actor UnixgramGateway {
    static let shared = UnixgramGateway()

    private let baseURL = URL(string: "https://web.unixgram.com")!
    private let session: URLSession
    private(set) var csrfToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    func bootstrapCSRF() async throws {
        let url = baseURL.appending(path: UnixgramDocumentedRoute.csrf)
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let token = object["token"] as? String {
                csrfToken = token
                return
            }
            if let dataObject = object["data"] as? [String: Any],
               let token = dataObject["token"] as? String {
                csrfToken = token
                return
            }
        }
    }

    func makeSSERequest() -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: UnixgramDocumentedRoute.realtimeSSE))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        return request
    }
}

@MainActor
final class UnixgramRealtimeStore: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var lastEventName: String?
    @Published private(set) var lastPayload: String?

    private var task: Task<Void, Never>?

    func connect() {
        disconnect()

        task = Task {
            let request = await UnixgramGateway.shared.makeSSERequest()
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    isConnected = false
                    return
                }

                isConnected = true

                for try await line in bytes.lines {
                    guard !Task.isCancelled else { break }

                    if line.hasPrefix("event:") {
                        lastEventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        lastPayload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    }
                }
            } catch {
                isConnected = false
            }
        }
    }

    func disconnect() {
        task?.cancel()
        task = nil
        isConnected = false
    }
}

actor UnixProtoNativeTransport {
    enum Transport: String, CaseIterable {
        case legacy
        case abridged
        case intermediate
        case paddedIntermediate
        case full
    }

    enum State: Equatable {
        case disconnected
        case waitingForOfficialGatewayConfiguration
    }

    private(set) var state: State = .disconnected

    func prepare() {
        // Public UnixProto documentation describes:
        // TCP framing, optional AES-256-CTR obfuscation,
        // X25519 key agreement, HKDF-SHA256, replay guard,
        // MessagePack WebSocket realtime and session recovery.
        //
        // It does not currently publish enough gateway/handshake constants
        // here to safely invent a production connection.
        state = .waitingForOfficialGatewayConfiguration
    }
}
