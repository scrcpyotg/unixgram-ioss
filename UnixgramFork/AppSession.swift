import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var isAuthenticated: Bool = false // legacy UI compatibility only
    @Published var isConversationOpen: Bool = false
    @Published var pendingNotificationDeepLink: UnixgramNotificationDeepLink?
    @Published var homeNavigationResetID = UUID()
    let api = APIClient.shared

    func returnToFeed() {
        pendingNotificationDeepLink = nil
        homeNavigationResetID = UUID()
        selectedTab = .home
    }
}

enum UnixgramNotificationDeepLink: Equatable {
    case post(postID: String, commentID: String?)
    case profile(username: String)
}

enum MainTab: Hashable {
    case home, discover, notifications, messages, stats, profile
}
