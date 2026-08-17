import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var isAuthenticated: Bool = false // legacy UI compatibility only
    @Published var isConversationOpen: Bool = false
    let api = APIClient.shared
}

enum MainTab: Hashable {
    case home, discover, notifications, messages, stats, profile
}
