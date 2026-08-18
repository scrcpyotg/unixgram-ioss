import Foundation
import AuthenticationServices
import UIKit

enum SoundCloudAuthError: LocalizedError {
    case brokerNotConfigured
    case invalidAuthorizationURL
    case callbackMissing
    case stateMismatch
    case authorizationDenied(String)
    case tokenExchangeFailed(String)
    case notAuthenticated
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .brokerNotConfigured:
            return "Сервер входа SoundCloud ещё не настроен."
        case .invalidAuthorizationURL:
            return "Не удалось создать ссылку авторизации SoundCloud."
        case .callbackMissing:
            return "SoundCloud не вернул код авторизации."
        case .stateMismatch:
            return "Проверка безопасности OAuth не пройдена. Попробуйте войти ещё раз."
        case .authorizationDenied(let message):
            return message.isEmpty ? "Вход SoundCloud отменён." : message
        case .tokenExchangeFailed(let message):
            return message.isEmpty ? "Не удалось получить токен SoundCloud." : message
        case .notAuthenticated:
            return "Войдите в SoundCloud."
        case .keychain(let status):
            return "Не удалось сохранить SoundCloud-сессию в Keychain (\(status))."
        }
    }
}

private struct SoundCloudBrokerRequest: Encodable {
    let action: String
    let code: String?
    let codeVerifier: String?
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case action, code
        case codeVerifier = "code_verifier"
        case refreshToken = "refresh_token"
    }
}

private struct SoundCloudBrokerError: Decodable {
    let error: String?
    let message: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error, message
        case errorDescription = "error_description"
    }

    var resolvedMessage: String {
        errorDescription ?? message ?? error ?? "SoundCloud token broker error"
    }
}

@MainActor
final class SoundCloudSession: NSObject, ObservableObject {
    static let shared = SoundCloudSession()

    @Published private(set) var account: SoundCloudMe?
    @Published private(set) var isRestoring = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isConnected = false
    @Published var errorMessage: String?

    private var token: SoundCloudOAuthToken?
    private var authSession: ASWebAuthenticationSession?
    private var restoreStarted = false

    override private init() {
        super.init()
        token = SoundCloudKeychain.loadToken()
        isConnected = token != nil
    }

    func restoreIfNeeded() async {
        guard !restoreStarted else { return }
        restoreStarted = true
        guard token != nil else { return }

        isRestoring = true
        defer { isRestoring = false }

        do {
            account = try await SoundCloudAPIClient.shared.me(session: self)
            isConnected = true
        } catch {
            // A temporary network failure must not erase a valid refresh token.
            errorMessage = error.localizedDescription
        }
    }

    func connect() async {
        guard !isAuthenticating else { return }
        guard SoundCloudConfig.brokerBaseURL != nil else {
            errorMessage = SoundCloudAuthError.brokerNotConfigured.localizedDescription
            return
        }

        errorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        let verifier = SoundCloudPKCE.verifier()
        let challenge = SoundCloudPKCE.challenge(for: verifier)
        let expectedState = SoundCloudPKCE.state()

        guard var components = URLComponents(string: "https://secure.soundcloud.com/authorize") else {
            errorMessage = SoundCloudAuthError.invalidAuthorizationURL.localizedDescription
            return
        }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: SoundCloudConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: SoundCloudConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: expectedState),
            URLQueryItem(name: "display", value: "popup")
        ]

        guard let authURL = components.url else {
            errorMessage = SoundCloudAuthError.invalidAuthorizationURL.localizedDescription
            return
        }

        do {
            let callbackURL = try await authenticate(url: authURL)

            guard let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                throw SoundCloudAuthError.callbackMissing
            }

            let items = callback.queryItems ?? []
            if let oauthError = items.first(where: { $0.name == "error" })?.value {
                let description = items.first(where: { $0.name == "error_description" })?.value ?? oauthError
                throw SoundCloudAuthError.authorizationDenied(description)
            }

            guard items.first(where: { $0.name == "state" })?.value == expectedState else {
                throw SoundCloudAuthError.stateMismatch
            }

            guard let code = items.first(where: { $0.name == "code" })?.value,
                  !code.isEmpty else {
                throw SoundCloudAuthError.callbackMissing
            }

            let received = try await broker(
                SoundCloudBrokerRequest(
                    action: "exchange",
                    code: code,
                    codeVerifier: verifier,
                    refreshToken: nil
                )
            ).withFreshExpiry()

            try SoundCloudKeychain.save(token: received)
            token = received
            isConnected = true

            account = try await SoundCloudAPIClient.shared.me(session: self)
        } catch is CancellationError {
            // User cancellation is not an app error.
        } catch let error as ASWebAuthenticationSessionError
            where error.code == .canceledLogin {
            // User cancellation is not an app error.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        if let access = token?.accessToken {
            var request = URLRequest(url: URL(string: "https://secure.soundcloud.com/sign-out")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["access_token": access])
            _ = try? await URLSession.shared.data(for: request)
        }

        authSession?.cancel()
        authSession = nil
        token = nil
        account = nil
        isConnected = false
        errorMessage = nil
        SoundCloudKeychain.clear()
    }

    func validAccessToken() async throws -> String {
        guard var token else { throw SoundCloudAuthError.notAuthenticated }

        if token.expiresAt.timeIntervalSinceNow > 90 {
            return token.accessToken
        }

        guard SoundCloudConfig.brokerBaseURL != nil else {
            throw SoundCloudAuthError.brokerNotConfigured
        }

        let refreshed = try await broker(
            SoundCloudBrokerRequest(
                action: "refresh",
                code: nil,
                codeVerifier: nil,
                refreshToken: token.refreshToken
            )
        ).withFreshExpiry()

        // Refresh tokens are single-use. Replace the whole record atomically.
        try SoundCloudKeychain.save(token: refreshed)
        self.token = refreshed
        token = refreshed
        isConnected = true
        return token.accessToken
    }

    func forceRefreshAccessToken() async throws -> String {
        guard let current = token else { throw SoundCloudAuthError.notAuthenticated }
        guard SoundCloudConfig.brokerBaseURL != nil else {
            throw SoundCloudAuthError.brokerNotConfigured
        }

        let refreshed = try await broker(
            SoundCloudBrokerRequest(
                action: "refresh",
                code: nil,
                codeVerifier: nil,
                refreshToken: current.refreshToken
            )
        ).withFreshExpiry()

        try SoundCloudKeychain.save(token: refreshed)
        token = refreshed
        isConnected = true
        return refreshed.accessToken
    }

    private func broker(_ payload: SoundCloudBrokerRequest) async throws -> SoundCloudOAuthToken {
        guard let url = SoundCloudConfig.brokerBaseURL else {
            throw SoundCloudAuthError.brokerNotConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SoundCloudAuthError.tokenExchangeFailed("Некорректный ответ token broker.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(SoundCloudBrokerError.self, from: data).resolvedMessage)
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(http.statusCode)"
            throw SoundCloudAuthError.tokenExchangeFailed(message)
        }

        do {
            return try JSONDecoder().decode(SoundCloudOAuthToken.self, from: data)
        } catch {
            throw SoundCloudAuthError.tokenExchangeFailed("Broker вернул неизвестный формат токена.")
        }
    }

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: SoundCloudConfig.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: SoundCloudAuthError.callbackMissing)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authSession = session

            guard session.start() else {
                continuation.resume(throwing: SoundCloudAuthError.authorizationDenied("Не удалось открыть SoundCloud."))
                return
            }
        }
    }
}

extension SoundCloudSession: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        if let window = scenes
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) {
            return window
        }

        return scenes.first?.windows.first ?? ASPresentationAnchor()
    }
}
