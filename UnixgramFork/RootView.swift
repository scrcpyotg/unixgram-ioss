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
                        .id(session.homeNavigationResetID)
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

            if let notice = liveSession.connectionNotice {
                VStack {
                    HStack(spacing: 9) {
                        if notice.contains("Обнов") {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        Text(notice)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
                .allowsHitTesting(false)
            }

            if musicPlayer.currentTrack != nil && !session.isConversationOpen {
                UnixgramMiniMusicPlayer()
                    .padding(.horizontal, 22)
                    .padding(.bottom, 82)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !session.isConversationOpen {
                UnixgramDock(
                    selected: $session.selectedTab,
                    unread: max(liveDashboard.notificationUnread, systemNotifications.socialUnread)
                )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            let postID = (notification.userInfo?["postId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let commentID = (notification.userInfo?["commentId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let actorUsername = (notification.userInfo?["actorUsername"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            if kind == UGNotificationKind.message.rawValue {
                session.pendingNotificationDeepLink = nil
                session.selectedTab = .messages
                return
            }

            if (kind == UGNotificationKind.follow.rawValue || kind == UGNotificationKind.support.rawValue),
               let actorUsername, !actorUsername.isEmpty {
                session.pendingNotificationDeepLink = .profile(username: actorUsername)
                session.selectedTab = .notifications
                return
            }

            if let postID, !postID.isEmpty {
                session.pendingNotificationDeepLink = .post(
                    postID: postID,
                    commentID: (commentID?.isEmpty == false) ? commentID : nil
                )
            } else {
                session.pendingNotificationDeepLink = nil
            }
            session.selectedTab = .notifications
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
                .fill(Color.black.opacity(0.76))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
