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

    private var didBootstrap = false

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await refreshAuthentication()
    }

    func refreshAuthentication() async {
        isLoading = true
        if currentUser == nil {
            launchState = .checking
        }

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

            // Prepare CSRF for real mutations such as sending messages.
            try? await UnixgramRealAPIClient.shared.bootstrapCSRF()
        } catch {
            currentUser = nil
            isAuthenticated = false
            launchState = .signedOut

            // A normal 401 on first launch is not shown as a scary error.
            if case UnixgramClientError.notAuthenticated = error {
                lastError = nil
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func markSignedOut() {
        currentUser = nil
        isAuthenticated = false
        launchState = .signedOut
        lastError = nil
    }
}
