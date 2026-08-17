import SwiftUI

struct UnixgramPostInteractionBar: View {
    let post: UGHARFeedPost
    var showViews: Bool = true
    var showBookmark: Bool = true

    @State private var liked: Bool
    @State private var reposted: Bool
    @State private var likesCount: Int
    @State private var commentsCount: Int
    @State private var repostsCount: Int
    @State private var isLiking = false
    @State private var isReposting = false
    @State private var showComments = false
    @State private var interactionError: String?

    init(
        post: UGHARFeedPost,
        showViews: Bool = true,
        showBookmark: Bool = true
    ) {
        self.post = post
        self.showViews = showViews
        self.showBookmark = showBookmark
        _liked = State(initialValue: post.likedByViewer ?? false)
        _reposted = State(initialValue: post.repostedByViewer ?? false)
        _likesCount = State(initialValue: post.likesCount ?? 0)
        _commentsCount = State(initialValue: post.commentsCount ?? 0)
        _repostsCount = State(initialValue: post.repostsCount ?? 0)
    }

    var body: some View {
        HStack(spacing: 18) {
            Button {
                Task { await toggleLike() }
            } label: {
                metric(liked ? "heart.fill" : "heart", likesCount, liked ? .pink : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isLiking)

            Button {
                showComments = true
            } label: {
                metric("bubble.left", commentsCount)
            }
            .buttonStyle(.plain)

            Button {
                Task { await toggleRepost() }
            } label: {
                metric("arrow.2.squarepath", repostsCount, reposted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isReposting)

            if showViews {
                metric("eye", post.viewsCount ?? 0)
            }

            Spacer()

            if showBookmark {
                metric(
                    post.bookmarkedByViewer == true ? "bookmark.fill" : "bookmark",
                    post.bookmarksCount ?? 0
                )
            }
        }
        .sheet(isPresented: $showComments) {
            UnixgramCommentsView(
                post: post,
                initialCommentsCount: commentsCount
            ) {
                commentsCount += 1
            }
        }
        .alert(
            "Unixgram",
            isPresented: Binding(
                get: { interactionError != nil },
                set: { if !$0 { interactionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(interactionError ?? "")
        }
    }

    private func toggleLike() async {
        guard !isLiking else { return }
        isLiking = true
        defer { isLiking = false }

        do {
            let result = try await UnixgramRealAPIClient.shared.togglePostLike(postId: post.id)
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                liked = result.liked
                likesCount = result.likesCount
            }
        } catch {
            interactionError = error.localizedDescription
        }
    }

    private func toggleRepost() async {
        guard !isReposting else { return }
        isReposting = true
        defer { isReposting = false }

        do {
            let oldValue = reposted
            let result = try await UnixgramRealAPIClient.shared.togglePostRepost(postId: post.id)

            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                reposted = result.reposted
                if oldValue != result.reposted {
                    repostsCount = max(0, repostsCount + (result.reposted ? 1 : -1))
                }
            }
        } catch {
            interactionError = error.localizedDescription
        }
    }

    private func metric(
        _ icon: String,
        _ value: Int,
        _ tint: Color = .secondary
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            if value > 0 {
                Text("\(value)")
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(tint)
        .contentShape(Rectangle())
    }
}

struct UnixgramCommentsView: View {
    let post: UGHARFeedPost
    let initialCommentsCount: Int
    let onCommentCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var comments: [UGPostComment] = []
    @State private var repliesByCommentID: [String: [UGPostComment]] = [:]
    @State private var expandedReplyIDs: Set<String> = []
    @State private var loadingReplyIDs: Set<String> = []
    @State private var text = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var sendError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        postPreview

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                        } else if comments.isEmpty {
                            emptyComments
                        } else {
                            ForEach(rootComments) { comment in
                                commentThread(comment)
                            }
                        }
                    }
                    .padding(16)
                }

                Divider().opacity(0.35)
                composer
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Комментарии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task {
                await loadCommentsBestEffort()
            }
            .alert(
                "Не удалось отправить",
                isPresented: Binding(
                    get: { sendError != nil },
                    set: { if !$0 { sendError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sendError ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private var postPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(post.author?.displayName ?? post.author?.username ?? post.community?.name ?? "Unixgram")
                .font(.headline)

            if let content = post.content, !content.isEmpty {
                UnixgramMentionText(
                    text: content,
                    font: .subheadline,
                    color: Color.white.opacity(0.65),
                    lineLimit: 3
                )
            }

            Text("\(max(initialCommentsCount, comments.count)) комментариев")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyComments: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            Text(initialCommentsCount > 0 ? "Напишите комментарий" : "Комментариев пока нет")
                .font(.headline)

            Text("Комментарий отправится в ваш настоящий аккаунт Unixgram.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Написать комментарий…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Button {
                Task { await sendComment() }
            } label: {
                Group {
                    if isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(width: 42, height: 42)
                .background(canSend ? Color.white : Color.white.opacity(0.12))
                .foregroundStyle(canSend ? Color.black : Color.secondary)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var rootComments: [UGPostComment] {
        comments.filter { $0.parentCommentId == nil }
    }

    private func localReplies(for commentID: String) -> [UGPostComment] {
        comments.filter { $0.parentCommentId == commentID }
    }

    private func loadCommentsBestEffort() async {
        defer { isLoading = false }

        do {
            let payload = try await UnixgramRealAPIClient.shared.postComments(
                postId: post.id,
                sort: "new",
                limit: 50
            )
            comments = payload.comments
        } catch {
            comments = []
        }
    }

    private func sendComment() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        isSending = true
        defer { isSending = false }

        do {
            let created = try await UnixgramRealAPIClient.shared.createPostComment(
                postId: post.id,
                content: trimmed
            )
            text = ""
            comments.append(created)
            onCommentCreated()
        } catch {
            sendError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func commentThread(_ comment: UGPostComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            commentRow(comment, isReply: false)

            let cachedReplies = repliesByCommentID[comment.id] ?? localReplies(for: comment.id)
            let knownReplyCount = max(comment.repliesCount ?? 0, cachedReplies.count)

            if knownReplyCount > 0 {
                Button {
                    Task { await toggleReplies(for: comment) }
                } label: {
                    HStack(spacing: 7) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 24, height: 1)

                        if loadingReplyIDs.contains(comment.id) {
                            ProgressView()
                                .controlSize(.mini)
                        }

                        Text(replyButtonTitle(for: comment, count: knownReplyCount))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 49)
                .disabled(loadingReplyIDs.contains(comment.id))
            }

            if expandedReplyIDs.contains(comment.id) {
                let replies = repliesByCommentID[comment.id] ?? cachedReplies

                if replies.isEmpty && !loadingReplyIDs.contains(comment.id) {
                    Text("Ответы пока не удалось загрузить")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 49)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(replies) { reply in
                            commentRow(reply, isReply: true)
                        }
                    }
                    .padding(.leading, 34)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func replyButtonTitle(for comment: UGPostComment, count: Int) -> String {
        if expandedReplyIDs.contains(comment.id) {
            return "Скрыть ответы"
        }

        let lastTwo = count % 100
        let last = count % 10
        let word: String
        if (11...14).contains(lastTwo) {
            word = "ответов"
        } else if last == 1 {
            word = "ответ"
        } else if (2...4).contains(last) {
            word = "ответа"
        } else {
            word = "ответов"
        }
        return "Показать \(count) \(word)"
    }

    @MainActor
    private func toggleReplies(for comment: UGPostComment) async {
        if expandedReplyIDs.contains(comment.id) {
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedReplyIDs.remove(comment.id)
            }
            return
        }

        let local = localReplies(for: comment.id)
        if !local.isEmpty {
            repliesByCommentID[comment.id] = local
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedReplyIDs.insert(comment.id)
            }
            return
        }

        if repliesByCommentID[comment.id] != nil {
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedReplyIDs.insert(comment.id)
            }
            return
        }

        loadingReplyIDs.insert(comment.id)
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedReplyIDs.insert(comment.id)
        }

        do {
            let replies = try await UnixgramRealAPIClient.shared.postCommentReplies(
                postId: post.id,
                commentId: comment.id,
                limit: 50
            )
            repliesByCommentID[comment.id] = replies
        } catch {
            repliesByCommentID[comment.id] = []
        }

        loadingReplyIDs.remove(comment.id)
    }

    private func commentRow(_ comment: UGPostComment, isReply: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            NavigationLink {
                UnixgramPublicProfileView(username: comment.author.username)
            } label: {
                commentAvatar(comment.author.avatarUrl, size: isReply ? 32 : 38)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    NavigationLink {
                        UnixgramPublicProfileView(username: comment.author.username)
                    } label: {
                        Text(comment.author.displayName ?? comment.author.username)
                            .font(.system(size: isReply ? 13 : 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    if comment.author.verificationBadge != nil,
                       comment.author.verificationBadge != "NONE" {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }

                    Spacer()

                    if let createdAt = comment.createdAt {
                        Text(relative(createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let content = comment.content, !content.isEmpty {
                    UnixgramMentionText(
                        text: content,
                        font: .system(size: isReply ? 14 : 15),
                        color: .white
                    )
                }

                if let raw = comment.imageUrl, let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(Color.white.opacity(0.05))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isReply ? 140 : 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let likes = comment.likesCount, likes > 0 {
                    Label(
                        "\(likes)",
                        systemImage: comment.likedByViewer == true ? "heart.fill" : "heart"
                    )
                    .font(.caption)
                    .foregroundStyle(comment.likedByViewer == true ? .pink : .secondary)
                }
            }
        }
        .padding(isReply ? 10 : 12)
        .background(Color.white.opacity(isReply ? 0.025 : 0.035))
        .clipShape(RoundedRectangle(cornerRadius: isReply ? 14 : 16))
    }

    @ViewBuilder
    private func commentAvatar(_ raw: String?, size: CGFloat = 38) -> some View {
        if let raw, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle().fill(Color.white.opacity(0.08))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: size, height: size)
        }
    }

    private func relative(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return "" }
        return date.formatted(.relative(presentation: .numeric))
    }
}
