import Foundation
import SwiftUI

@MainActor
final class UnixgramLiveSession: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: UGCurrentAccount?
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    func refreshAuthentication() async {
        isLoading = true
        defer { isLoading = false }

        do {
            await UnixgramRealAPIClient.shared.importWebKitCookies()
            let user = try await UnixgramRealAPIClient.shared.me()
            currentUser = user
            isAuthenticated = true
            lastError = nil

            // Also prepare CSRF for subsequent message mutations.
            try? await UnixgramRealAPIClient.shared.bootstrapCSRF()
        } catch {
            currentUser = nil
            isAuthenticated = false
            lastError = error.localizedDescription
        }
    }
}
