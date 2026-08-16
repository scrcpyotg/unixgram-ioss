import SwiftUI

@main
struct UnixgramForkApp: App {
    @UIApplicationDelegateAdaptor(UnixgramPushAppDelegate.self) private var appDelegate

    @StateObject private var session = AppSession()
    @StateObject private var liveSession = UnixgramLiveSession()
    @StateObject private var liveDashboard = UnixgramLiveDashboardStore()
    @StateObject private var systemNotifications = UnixgramSystemNotificationCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(liveSession)
                .environmentObject(liveDashboard)
                .environmentObject(systemNotifications)
        }
    }
}
