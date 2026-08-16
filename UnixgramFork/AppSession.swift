import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated = false
    @Published var selectedTab: MainTab = .home
    @Published var currentUser = UserProfile.mock
    let api = APIClient.shared
}

enum MainTab: Hashable {
    case home, discover, notifications, messages, stats, profile
}
