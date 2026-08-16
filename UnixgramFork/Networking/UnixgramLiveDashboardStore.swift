import Foundation
import SwiftUI

@MainActor
final class UnixgramLiveDashboardStore: ObservableObject {
    @Published var notificationUnread = 0
    @Published var messagesUnread = 0
    @Published var people: [UGSuggestedPerson] = []
    @Published var drafts: [UGDraftDTO] = []
    @Published var verification: UGVerificationRequest?
    @Published var folders: [UGMessageFolder] = []
    @Published var communities: [UGCommunityDTO] = []
    @Published var adminedCommunities: [UGAdminedCommunityDTO] = []

    @Published var feed: [UGHARFeedPost] = []
    @Published var feedCursor: String?
    @Published var feedHasMore = false
    @Published var trends: [UGFeedTrend] = []

    @Published var errorMessage: String?
    @Published var feedErrorMessage: String?
    @Published var isRefreshing = false

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Feed is critical: load it independently.
        // In v0.15 one unrelated decode error (messages unread count)
        // prevented the successfully returned feed from ever being assigned.
        await refreshFeed()

        // Everything below is supplemental. A failure in any one endpoint
        // must not break the rest of the application.
        async let notificationTask = safe { try await UnixgramRealAPIClient.shared.notificationsUnreadCount() }
        async let messagesTask = safe { try await UnixgramRealAPIClient.shared.messagesUnreadCount() }
        async let peopleTask = safe { try await UnixgramRealAPIClient.shared.peopleYouMayKnow() }
        async let draftsTask = safe { try await UnixgramRealAPIClient.shared.drafts() }
        async let verificationTask = safe { try await UnixgramRealAPIClient.shared.verificationRequest() }
        async let foldersTask = safe { try await UnixgramRealAPIClient.shared.messageFolders() }
        async let communitiesTask = safe { try await UnixgramRealAPIClient.shared.communities() }
        async let adminedTask = safe { try await UnixgramRealAPIClient.shared.adminedCommunities() }

        let notificationResult = await notificationTask
        let messagesResult = await messagesTask
        let peopleResult = await peopleTask
        let draftsResult = await draftsTask
        let verificationResult = await verificationTask
        let foldersResult = await foldersTask
        let communitiesResult = await communitiesTask
        let adminedResult = await adminedTask

        if let value = notificationResult { notificationUnread = value }
        if let value = messagesResult { messagesUnread = value }
        if let value = peopleResult { people = value }
        if let value = draftsResult { drafts = value }
        if let value = verificationResult { verification = value }
        if let value = foldersResult { folders = value }
        if let value = communitiesResult { communities = value }
        if let value = adminedResult { adminedCommunities = value }
    }

    func refreshFeed() async {
        do {
            let timeline = try await UnixgramRealAPIClient.shared.realFeed(limit: 15)

            feed = timeline.feed
            feedCursor = timeline.pageInfo.nextCursor
            feedHasMore = timeline.pageInfo.hasMore
            trends = timeline.trends ?? []

            // The feed response itself also returns suggestions.
            // Use them immediately when available.
            if let suggestions = timeline.suggestions, !suggestions.isEmpty {
                people = suggestions
            }

            feedErrorMessage = nil
            errorMessage = nil
        } catch {
            feedErrorMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }
    }

    func appendNextFeedPage() async {
        guard feedHasMore,
              let cursor = feedCursor,
              !cursor.isEmpty else { return }

        do {
            let timeline = try await UnixgramRealAPIClient.shared.realFeed(
                limit: 15,
                cursor: cursor
            )

            let existing = Set(feed.map(\.id))
            feed.append(contentsOf: timeline.feed.filter { !existing.contains($0.id) })
            feedCursor = timeline.pageInfo.nextCursor
            feedHasMore = timeline.pageInfo.hasMore
            feedErrorMessage = nil
        } catch {
            feedErrorMessage = error.localizedDescription
        }
    }

    private func safe<T>(_ operation: @escaping () async throws -> T) async -> T? {
        do {
            return try await operation()
        } catch {
            // Keep partial app data alive. Do not turn a secondary endpoint
            // into a global refresh failure.
            return nil
        }
    }
}
