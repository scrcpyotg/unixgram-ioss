import Foundation
import SwiftUI

@MainActor
final class UnixgramProfileContentStore: ObservableObject {
    @Published var profile: UGPublicProfile?
    @Published var posts: [UGHARFeedPost] = []
    @Published var replies: [UGHARFeedPost] = []
    @Published var media: [UGHARFeedPost] = []
    @Published var stories: [UGProfileStory] = []
    @Published var gifts: [UGProfileGift] = []

    @Published var postsPageInfo: UGProfilePageInfo?
    @Published var repliesPageInfo: UGProfilePageInfo?
    @Published var mediaPageInfo: UGProfilePageInfo?

    @Published var isLoadingHeader = false
    @Published var isLoadingTab = false
    @Published var errorMessage: String?

    private var loadedTabs = Set<UnixgramProfileTab>()

    func refresh(username: String, selectedTab: UnixgramProfileTab) async {
        async let header: Void = loadHeader(username: username)
        async let tab: Void = load(tab: selectedTab, username: username, force: true)
        _ = await (header, tab)
    }

    func loadHeader(username: String) async {
        isLoadingHeader = true
        defer { isLoadingHeader = false }

        do {
            profile = try await UnixgramRealAPIClient.shared.publicProfile(username: username)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load(tab: UnixgramProfileTab, username: String, force: Bool = false) async {
        if !force && loadedTabs.contains(tab) {
            return
        }

        isLoadingTab = true
        defer { isLoadingTab = false }

        do {
            switch tab {
            case .posts:
                let result = try await UnixgramRealAPIClient.shared.profilePosts(username: username)
                posts = result.posts
                postsPageInfo = result.pageInfo

            case .stories:
                stories = try await UnixgramRealAPIClient.shared.profileStories(username: username)

            case .replies:
                let result = try await UnixgramRealAPIClient.shared.profileReplies(username: username)
                replies = result.replies
                repliesPageInfo = result.pageInfo

            case .media:
                let result = try await UnixgramRealAPIClient.shared.profileMedia(username: username)
                media = result.posts
                mediaPageInfo = result.pageInfo

            case .gifts:
                let result = try await UnixgramRealAPIClient.shared.profileGifts(username: username)
                gifts = result.gifts
            }

            loadedTabs.insert(tab)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(tab: UnixgramProfileTab, username: String) async {
        do {
            switch tab {
            case .posts:
                guard postsPageInfo?.hasMore == true,
                      let cursor = postsPageInfo?.cursor else { return }
                let result = try await UnixgramRealAPIClient.shared.profilePosts(
                    username: username,
                    cursor: cursor
                )
                appendUnique(result.posts, to: &posts)
                postsPageInfo = result.pageInfo

            case .replies:
                guard repliesPageInfo?.hasMore == true,
                      let cursor = repliesPageInfo?.cursor else { return }
                let result = try await UnixgramRealAPIClient.shared.profileReplies(
                    username: username,
                    cursor: cursor
                )
                appendUnique(result.replies, to: &replies)
                repliesPageInfo = result.pageInfo

            case .media:
                guard mediaPageInfo?.hasMore == true,
                      let cursor = mediaPageInfo?.cursor else { return }
                let result = try await UnixgramRealAPIClient.shared.profileMedia(
                    username: username,
                    cursor: cursor
                )
                appendUnique(result.posts, to: &media)
                mediaPageInfo = result.pageInfo

            case .stories, .gifts:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appendUnique(_ incoming: [UGHARFeedPost], to target: inout [UGHARFeedPost]) {
        let existing = Set(target.map(\.id))
        target.append(contentsOf: incoming.filter { !existing.contains($0.id) })
    }
}

enum UnixgramProfileTab: String, CaseIterable, Hashable {
    case posts
    case stories
    case replies
    case media
    case gifts

    var title: String {
        switch self {
        case .posts: "Posts"
        case .stories: "Stories"
        case .replies: "Replies"
        case .media: "Media"
        case .gifts: "Gifts"
        }
    }
}
