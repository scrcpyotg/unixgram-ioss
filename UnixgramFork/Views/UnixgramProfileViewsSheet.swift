import SwiftUI

struct UnixgramProfileViewsSheet: View {
    let summary: UGProfileViews?

    @Environment(\.dismiss) private var dismiss
    @State private var recentViewers: [UGProfileViewUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && recentViewers.isEmpty {
                    ProgressView("Загружаем просмотры…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recentViewers.isEmpty {
                    ContentUnavailableView(
                        "Пока нет просмотров",
                        systemImage: "eye",
                        description: Text(emptyDescription)
                    )
                } else {
                    List(recentViewers) { viewer in
                        if let username = viewer.username, !username.isEmpty {
                            NavigationLink {
                                UnixgramPublicProfileView(username: username)
                            } label: {
                                viewerRow(viewer)
                            }
                            .listRowBackground(Color.black)
                        } else {
                            viewerRow(viewer)
                                .listRowBackground(Color.black)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
        .preferredColorScheme(.dark)
    }

    private var title: String {
        let count = summary?.totalCount ?? 0
        return count > 0 ? "Просмотры профиля · \(count)" : "Просмотры профиля"
    }

    private var emptyDescription: String {
        if let errorMessage, !errorMessage.isEmpty { return errorMessage }
        if let count = summary?.totalCount, count > 0 {
            return "Unixgram показывает \(count) просмотров, но список последних пользователей пока не пришёл в уведомлениях."
        }
        return "Когда пользователи откроют ваш профиль, они появятся здесь."
    }

    @ViewBuilder
    private func viewerRow(_ viewer: UGProfileViewUser) -> some View {
        HStack(spacing: 12) {
            avatar(viewer)
                .frame(width: 50, height: 50)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(viewer.displayName ?? viewer.username ?? "Пользователь Unixgram")
                    .font(.system(size: 16, weight: .semibold))

                if let username = viewer.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "eye.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func avatar(_ viewer: UGProfileViewUser) -> some View {
        if let raw = viewer.avatarUrl, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: avatarFallback(viewer)
                }
            }
        } else {
            avatarFallback(viewer)
        }
    }

    private func avatarFallback(_ viewer: UGProfileViewUser) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                Text(String((viewer.displayName ?? viewer.username ?? "U").prefix(1)).uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(.secondary)
            }
    }

    @MainActor
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await UnixgramRealAPIClient.shared.notifications(limit: 100)
            var found: [UGProfileViewUser] = []
            var seen = Set<String>()

            for item in page.notifications where isProfileViewNotification(item) {
                guard let actor = item.actor else { continue }
                let viewer = UGProfileViewUser(
                    rawID: actor.id,
                    username: actor.username,
                    displayName: actor.displayName,
                    avatarUrl: actor.avatarURL
                )
                let key = viewer.rawID ?? viewer.username?.lowercased() ?? viewer.avatarUrl ?? UUID().uuidString
                if seen.insert(key).inserted {
                    found.append(viewer)
                }
            }

            if let last = summary?.lastViewer {
                let key = last.rawID ?? last.username?.lowercased() ?? last.avatarUrl ?? "last-viewer"
                if seen.insert(key).inserted {
                    found.insert(last, at: 0)
                }
            }

            recentViewers = found
            errorMessage = nil
        } catch {
            if let last = summary?.lastViewer {
                recentViewers = [last]
            }
            errorMessage = error.localizedDescription
        }
    }

    private func isProfileViewNotification(_ item: UGNotificationItem) -> Bool {
        let haystack = [item.type, item.title ?? "", item.body ?? ""]
            .joined(separator: " ")
            .lowercased()

        return haystack.contains("profile_view")
            || haystack.contains("profileview")
            || haystack.contains("profile view")
            || haystack.contains("просмотр профиля")
            || haystack.contains("посмотрел ваш профиль")
            || haystack.contains("открыл ваш профиль")
    }
}
