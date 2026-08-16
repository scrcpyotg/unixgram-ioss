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
    @Published var errorMessage: String?
    @Published var isRefreshing = false

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let n = UnixgramRealAPIClient.shared.notificationsUnreadCount()
            async let m = UnixgramRealAPIClient.shared.messagesUnreadCount()
            async let p = UnixgramRealAPIClient.shared.peopleYouMayKnow()
            async let d = UnixgramRealAPIClient.shared.drafts()
            async let v = UnixgramRealAPIClient.shared.verificationRequest()
            async let f = UnixgramRealAPIClient.shared.messageFolders()
            async let c = UnixgramRealAPIClient.shared.communities()
            async let a = UnixgramRealAPIClient.shared.adminedCommunities()
            async let timeline = UnixgramRealAPIClient.shared.realFeed(limit: 15)

            let result = try await (n, m, p, d, v, f, c, a, timeline)

            notificationUnread = result.0
            messagesUnread = result.1
            people = result.2
            drafts = result.3
            verification = result.4
            folders = result.5
            communities = result.6
            adminedCommunities = result.7
            feed = result.8.feed
            feedCursor = result.8.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
