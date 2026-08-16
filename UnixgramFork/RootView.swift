import SwiftUI

struct RootView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    var body: some View {
        Group {
            switch liveSession.launchState {
            case .checking:
                UnixgramLaunchCheckingView()

            case .signedOut:
                UnixgramLaunchAuthView()

            case .signedIn:
                MainShellView()
            }
        }
        .background(UGTheme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            await liveSession.bootstrapIfNeeded()
        }
    }
}

struct MainShellView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @EnvironmentObject private var liveDashboard: UnixgramLiveDashboardStore
    @EnvironmentObject private var systemNotifications: UnixgramSystemNotificationCenter
    @ObservedObject private var musicPlayer = UnixgramMusicPlayer.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch session.selectedTab {
                case .home:
                    NavigationStack { UnixgramAllRealFeedView() }
                case .discover:
                    NavigationStack { UnixgramAllRealDiscoverView() }
                case .notifications:
                    NavigationStack { UnixgramAllRealNotificationsView() }
                case .messages:
                    NavigationStack { UnixgramRealMessagesView() }
                case .stats:
                    NavigationStack { UnixgramAllRealCreatorStudioView() }
                case .profile:
                    NavigationStack { UnixgramRealProfileView() }
                }
            }
            .padding(.bottom, musicPlayer.currentTrack == nil ? 86 : 154)

            if musicPlayer.currentTrack != nil {
                UnixgramMiniMusicPlayer()
                    .padding(.horizontal, 22)
                    .padding(.bottom, 82)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            UnixgramDock(
                selected: $session.selectedTab,
                unread: max(liveDashboard.notificationUnread, systemNotifications.socialUnread)
            )
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            if liveDashboard.feed.isEmpty {
                await liveDashboard.refreshAll()
            }

            if let userID = liveSession.currentUser?.id {
                await systemNotifications.activate(currentUserID: userID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .unixgramSystemNotificationTapped)) { notification in
            let kind = notification.userInfo?["kind"] as? String
            if kind == UGNotificationKind.message.rawValue {
                session.selectedTab = .messages
            } else {
                session.selectedTab = .notifications
            }
        }
    }
}

private struct UnixgramDock: View {
    @Binding var selected: MainTab
    var unread: Int

    private let items: [(MainTab, String)] = [
        (.home, "house"),
        (.discover, "safari"),
        (.notifications, "bell"),
        (.messages, "envelope"),
        (.stats, "chart.bar"),
        (.profile, "person.crop.circle")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { tab, icon in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selected = tab
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: selected == tab ? "\(icon).fill" : icon)
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(selected == tab ? Color.white : Color.white.opacity(0.68))
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selected == tab ? Color.white.opacity(0.08) : Color.clear)
                            )

                        if tab == .notifications && unread > 0 {
                            Text("\(unread)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(Color.purple)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.93))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
