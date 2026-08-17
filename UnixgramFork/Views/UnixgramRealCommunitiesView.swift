import SwiftUI

struct UnixgramRealCommunitiesView: View {
    @State private var tab: CommunityTab = .mine
    @State private var communities: [UGCommunityDTO] = []
    @State private var admined: [UGAdminedCommunityDTO] = []
    @State private var search = ""
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            searchBar

            Group {
                if loading && communities.isEmpty && admined.isEmpty {
                    ProgressView("Загружаем сообщества…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
        }
        .background(Color.black)
        .navigationBarHidden(true)
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Ошибка сообществ", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Text("Сообщества")
                .font(.system(size: 30, weight: .bold))

            Spacer()

            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.purple)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(CommunityTab.allCases, id: \.rawValue) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        tab = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tab == item ? Color.black : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(tab == item ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 18)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск сообществ", text: $search)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .mine:
            mineList
        case .overview:
            overviewList
        }
    }

    private var mineList: some View {
        List(filteredAdmined) { community in
            NavigationLink {
                UnixgramRealCommunityDetailView(
                    community: UGCommunityDTO(
                        id: community.id,
                        type: nil,
                        handle: community.handle,
                        handleAliases: nil,
                        name: community.name,
                        description: nil,
                        avatarUrl: community.avatarUrl,
                        bannerUrl: nil,
                        location: nil,
                        website: nil,
                        category: nil,
                        verified: community.verified,
                        membersCount: community.subscribersCount,
                        postsCount: nil,
                        createdAt: nil,
                        viewerRole: "admin",
                        isMember: true,
                        canPost: true,
                        isOwner: nil
                    )
                )
            } label: {
                communityRow(
                    name: community.name,
                    handle: community.handle,
                    avatar: community.avatarUrl,
                    verified: community.verified,
                    members: community.subscribersCount,
                    role: "Администратор"
                )
            }
            .listRowBackground(Color.black)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var overviewList: some View {
        List(filteredCommunities) { community in
            NavigationLink {
                UnixgramRealCommunityDetailView(community: community)
            } label: {
                communityRow(
                    name: community.name,
                    handle: community.handle,
                    avatar: community.avatarUrl,
                    verified: community.verified,
                    members: community.membersCount,
                    role: community.viewerRole
                )
            }
            .listRowBackground(Color.black)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func communityRow(
        name: String,
        handle: String,
        avatar: String?,
        verified: Bool?,
        members: Int?,
        role: String?
    ) -> some View {
        HStack(spacing: 12) {
            Group {
                if let avatar, let url = URL(string: avatar) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Circle().fill(Color.white.opacity(0.08))
                        }
                    }
                } else {
                    Circle().fill(Color.white.opacity(0.08))
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold))
                    if verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                            .font(.caption)
                    }
                }

                Text("@\(handle)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if let members {
                        Text("\(members) участников")
                    }
                    if let role, !role.isEmpty {
                        Text("• \(role)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var filteredCommunities: [UGCommunityDTO] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return communities }
        return communities.filter {
            $0.name.lowercased().contains(q) || $0.handle.lowercased().contains(q)
        }
    }

    private var filteredAdmined: [UGAdminedCommunityDTO] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return admined }
        return admined.filter {
            $0.name.lowercased().contains(q) || $0.handle.lowercased().contains(q)
        }
    }

    private func reload() async {
        loading = true
        defer { loading = false }

        do {
            async let all = UnixgramRealAPIClient.shared.communities()
            async let mine = UnixgramRealAPIClient.shared.adminedCommunities()
            let (allResult, mineResult) = try await (all, mine)
            communities = allResult
            admined = mineResult
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum CommunityTab: String, CaseIterable {
    case mine, overview

    var title: String {
        switch self {
        case .mine: "Мои"
        case .overview: "Обзор"
        }
    }
}

struct UnixgramRealCommunityDetailView: View {
    let community: UGCommunityDTO

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                banner

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        avatar
                            .frame(width: 108, height: 108)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 4))
                            .offset(y: -54)

                        Spacer()

                        if community.isMember == true {
                            Text("Вы подписаны")
                                .font(.system(size: 15, weight: .bold))
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, -54)

                    HStack(spacing: 7) {
                        Text(community.name)
                            .font(.system(size: 27, weight: .bold))
                        if community.verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.cyan)
                        }
                    }

                    Text("@\(community.handle)")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)

                    if let description = community.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 17))
                    }

                    HStack(spacing: 16) {
                        if let count = community.membersCount {
                            stat("\(count)", "участников")
                        }
                        if let count = community.postsCount {
                            stat("\(count)", "постов")
                        }
                    }

                    if let location = community.location {
                        meta("location", location)
                    }

                    if let website = community.website {
                        meta("link", website)
                    }

                    if let category = community.category {
                        meta("tag", category)
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack {
                        ForEach(["Посты", "Stories", "Медиа", "Подарки"], id: \.self) { item in
                            Text(item)
                                .font(.system(size: 15, weight: item == "Посты" ? .bold : .regular))
                                .foregroundStyle(item == "Посты" ? Color.white : Color.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)

                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.person.crop")
                            .font(.system(size: 38))
                            .foregroundStyle(.secondary)
                        Text("Посты сообщества будут подключены следующим запросом detail/posts.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                }
                .padding(.horizontal, 18)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var banner: some View {
        if let raw = community.bannerUrl, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: fallbackBanner
                }
            }
            .frame(height: 260)
            .clipped()
        } else {
            fallbackBanner.frame(height: 260)
        }
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [.purple.opacity(0.45), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var avatar: some View {
        if let raw = community.avatarUrl, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: Circle().fill(Color.white.opacity(0.08))
                }
            }
        } else {
            Circle().fill(Color.white.opacity(0.08))
        }
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func meta(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).foregroundStyle(.secondary)
        }
    }
}
