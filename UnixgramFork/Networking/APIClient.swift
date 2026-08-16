import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var csrfToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = .shared
        self.session = URLSession(configuration: config)
    }

    func bootstrapCSRF() async throws {
        let url = APIConfig.baseURL.appending(path: APIConfig.csrfPath)
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Реальная форма ответа может содержать token внутри envelope.
        // Сохраняем generic parsing до публикации per-method schema.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let token = json["token"] as? String {
                csrfToken = token
            } else if let data = json["data"] as? [String: Any],
                      let token = data["token"] as? String {
                csrfToken = token
            }
        }
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        let url = APIConfig.baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if method != "GET", let csrfToken {
            request.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 429 {
            throw APIClientError.rateLimited
        }

        let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
        if envelope.success, let value = envelope.data {
            return value
        }
        throw envelope.error ?? APIClientError.unknown
    }
}

enum APIClientError: Error {
    case rateLimited
    case unknown
}
