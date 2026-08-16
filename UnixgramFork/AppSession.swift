import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    @Published var selectedTab: MainTab = .home
    let api = APIClient.shared
}

enum MainTab: Hashable {
    case home, discover, notifications, messages, stats, profile
}
