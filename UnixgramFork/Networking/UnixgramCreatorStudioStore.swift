import Foundation
import SwiftUI

@MainActor
final class UnixgramCreatorStudioStore: ObservableObject {
    @Published private(set) var profile: UGPublicProfile?
    @Published private(set) var posts: [UGHARFeedPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var loadedUsername: String?

    var postsCount: Int { profile?.postsCount ?? posts.count }
    var followersCount: Int { profile?.followersCount ?? 0 }
    var followingCount: Int { profile?.followingCount ?? 0 }
    var storiesCount: Int { profile?.storiesCount ?? 0 }
    var viewsCount: Int { posts.compactMap(\.viewsCount).reduce(0, +) }
    var uniqueViewsCount: Int { posts.compactMap(\.uniqueViewsCount).reduce(0, +) }
    var likesCount: Int { posts.compactMap(\.likesCount).reduce(0, +) }
    var commentsCount: Int { posts.compactMap(\.commentsCount).reduce(0, +) }
    var repostsCount: Int { posts.compactMap(\.repostsCount).reduce(0, +) }
    var bookmarksCount: Int { posts.compactMap(\.bookmarksCount).reduce(0, +) }

    func load(username: String, force: Bool = false) async {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if !force, loadedUsername == normalized, profile != nil { return }
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            async let profileTask = UnixgramRealAPIClient.shared.publicProfile(username: normalized)
            let allPosts = try await loadAllProfilePosts(username: normalized)
            let loadedProfile = try await profileTask

            profile = loadedProfile
            posts = allPosts
            loadedUsername = normalized
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadAllProfilePosts(username: String) async throws -> [UGHARFeedPost] {
        var result: [UGHARFeedPost] = []
        var seen = Set<String>()
        var cursor: String?
        var page = 0

        // Hard ceiling protects the client from a malformed cursor loop while still
        // allowing a large creator profile to be aggregated from real profile pages.
        while page < 80 {
            let response = try await UnixgramRealAPIClient.shared.profilePosts(
                username: username,
                cursor: cursor,
                limit: 50
            )

            for post in response.posts where !seen.contains(post.id) {
                seen.insert(post.id)
                result.append(post)
            }

            guard response.pageInfo?.hasMore == true,
                  let next = response.pageInfo?.cursor,
                  !next.isEmpty,
                  next != cursor else {
                break
            }

            cursor = next
            page += 1
        }

        return result
    }
}
