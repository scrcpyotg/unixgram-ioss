import SwiftUI

struct UnixgramAllRealDiscoverView: View {
    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Обзор")
                    .font(.system(size: 32, weight: .bold))

                searchBar

                if !store.people.isEmpty {
                    sectionTitle("Возможно, вы знакомы")
                    peopleStrip
                }

                sectionTitle("Сообщества")

                ForEach(filteredCommunities) { community in
                    NavigationLink {
                        UnixgramRealCommunityDetailView(community: community)
                    } label: {
                        communityRow(community)
                    }
                    .buttonStyle(.plain)
                }

                if !store.adminedCommunities.isEmpty {
                    sectionTitle("Вы администрируете")

                    ForEach(store.adminedCommunities) { channel in
                        HStack(spacing: 12) {
                            avatar(channel.avatarUrl, size: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(channel.name).font(.headline)
                                Text("@\(channel.handle)").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Админ")
                                .font(.caption.bold())
                                .foregroundStyle(.purple)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 26)
        }
        .background(Color.black)
        .task {
            if store.communities.isEmpty && store.people.isEmpty {
                await store.refreshAll()
            }
        }
        .refreshable {
            await store.refreshAll()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Поиск людей и сообществ", text: $search)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var peopleStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.people) { person in
                    VStack(spacing: 8) {
                        avatar(person.avatarUrl, size: 72)
                        Text(person.displayName ?? person.username)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text("@\(person.username)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let label = person.reason?.label {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: 120)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private func communityRow(_ community: UGCommunityDTO) -> some View {
        HStack(spacing: 12) {
            avatar(community.avatarUrl, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(community.name)
                        .font(.system(size: 17, weight: .bold))
                    if community.verified == true {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.cyan)
                    }
                }

                Text("@\(community.handle)")
                    .foregroundStyle(.secondary)

                if let members = community.membersCount {
                    Text("\(members) участников")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if community.isMember == true {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var filteredCommunities: [UGCommunityDTO] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.communities }
        return store.communities.filter {
            $0.name.lowercased().contains(q) ||
            $0.handle.lowercased().contains(q)
        }
    }

    private func avatar(_ raw: String?, size: CGFloat) -> some View {
        Group {
            if let raw, let url = URL(string: raw) {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 22, weight: .bold))
    }
}
