import Foundation
import SwiftUI

@MainActor
final class UnixgramLiveSession: ObservableObject {
    enum LaunchState: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    @Published private(set) var launchState: LaunchState = .checking
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: UGCurrentAccount?
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published private(set) var connectionNotice: String?

    private var didBootstrap = false
    private var noticeTask: Task<Void, Never>?
    private let cachedAccountKey = "unixgram.cached.current.account.v1"

    init() {
        // Keep the last confirmed account locally. This is NOT a password or a session
        // secret; it only lets the UI stay usable when the network is temporarily down.
        if let data = UserDefaults.standard.data(forKey: cachedAccountKey),
           let account = try? JSONDecoder().decode(UGCurrentAccount.self, from: data) {
            currentUser = account
            isAuthenticated = true
            launchState = .signedIn
        }
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        // If a confirmed account is cached, render the app immediately and verify the
        // remote session without replacing the whole interface with the login screen.
        await refreshAuthentication(showCheckingState: currentUser == nil)
    }

    func refreshAuthentication(showCheckingState: Bool = false) async {
        guard !isLoading else { return }

        isLoading = true
        if showCheckingState && currentUser == nil {
            launchState = .checking
        }
        showNotice("Обновляем…", autoHideAfter: nil)

        defer { isLoading = false }

        do {
            // WKWebsiteDataStore.default persists the official Unixgram web session
            // between launches. Import those cookies into the API URLSession first.
            await UnixgramRealAPIClient.shared.importWebKitCookies()

            let user = try await UnixgramRealAPIClient.shared.me()
            currentUser = user
            isAuthenticated = true
            launchState = .signedIn
            lastError = nil
            cache(user)
            showNotice("Обновлено", autoHideAfter: 1.1)

            // Prepare CSRF for real mutations such as sending messages.
            try? await UnixgramRealAPIClient.shared.bootstrapCSRF()
        } catch {
            if case UnixgramClientError.notAuthenticated = error {
                // Only a confirmed HTTP 401 is allowed to destroy the local signed-in
                // state. Network failures, cancelled refreshes and Cloudflare pages must
                // never throw the user back to the authorization screen.
                await UnixgramRealAPIClient.shared.clearPersistedSession()
                clearCachedAccount()
                currentUser = nil
                isAuthenticated = false
                launchState = .signedOut
                lastError = nil
                showNotice(nil, autoHideAfter: nil)
            } else if currentUser != nil || isAuthenticated {
                // Preserve the last known-good session/UI while offline.
                isAuthenticated = true
                launchState = .signedIn
                lastError = nil
                showNotice("Нет соединения — показаны последние данные", autoHideAfter: 2.6)
            } else {
                // First ever launch with no cached account: do not claim the user is
                // signed out merely because the network is unavailable. Keep the checking
                // screen and show a retryable connection state instead.
                launchState = .checking
                isAuthenticated = false
                lastError = error.localizedDescription
                showNotice("Нет соединения. Проверим сессию позже", autoHideAfter: 2.8)
            }
        }
    }

    func markSignedOut() {
        clearCachedAccount()
        currentUser = nil
        isAuthenticated = false
        launchState = .signedOut
        lastError = nil
        showNotice(nil, autoHideAfter: nil)

        Task {
            await UnixgramRealAPIClient.shared.clearPersistedSession()
        }
    }

    func showRefreshingNotice() {
        showNotice("Обновляем…", autoHideAfter: nil)
    }

    func showOfflineNotice() {
        showNotice("Нет соединения — показаны последние данные", autoHideAfter: 2.6)
    }

    func hideNotice(after delay: Double = 0.8) {
        guard connectionNotice != nil else { return }
        let current = connectionNotice
        showNotice(current, autoHideAfter: delay)
    }

    private func cache(_ account: UGCurrentAccount) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        UserDefaults.standard.set(data, forKey: cachedAccountKey)
    }

    private func clearCachedAccount() {
        UserDefaults.standard.removeObject(forKey: cachedAccountKey)
    }

    private func showNotice(_ text: String?, autoHideAfter delay: Double?) {
        noticeTask?.cancel()
        noticeTask = nil
        connectionNotice = text

        guard let delay, text != nil else { return }
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.connectionNotice = nil
            }
        }
    }
}
