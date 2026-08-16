import SwiftUI

@main
struct UnixgramForkApp: App {
    @StateObject private var session = AppSession()
    @StateObject private var liveSession = UnixgramLiveSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(liveSession)
        }
    }
}
