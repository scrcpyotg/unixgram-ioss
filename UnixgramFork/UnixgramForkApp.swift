import SwiftUI

@main
struct UnixgramForkApp: App {
    @StateObject private var session = AppSession()
    @StateObject private var liveSession = UnixgramLiveSession()
    @StateObject private var liveDashboard = UnixgramLiveDashboardStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(liveSession)
                .environmentObject(liveDashboard)
        }
    }
}
