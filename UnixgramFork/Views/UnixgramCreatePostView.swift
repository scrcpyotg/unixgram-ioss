import SwiftUI
import PhotosUI
import UIKit

struct UnixgramCreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @EnvironmentObject private var dashboard: UnixgramLiveDashboardStore

    @State private var content = ""
    @State private var isPublishing = false
    @State private var errorMessage: String?

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [PreparedPostImage] = []
    @State private var isPreparingPhoto = false

    let onPublished: (() -> Void)?

    init(onPublished: (() -> Void)? = nil) {
        self.onPublished = onPublished
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                Divider()
                    .overlay(Color.white.opacity(0.08))

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        authorRow

                        VStack(alignment: .trailing, spacing: 6) {
                            TextEditor(text: $content)
                                .font(.system(size: 18))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 150)
                                .padding(.horizontal, 2)
                                .overlay(alignment: .topLeading) {
                                    if content.isEmpty {
                                        Text("Что нового?")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            .padding(.leading, 5)
                                            .allowsHitTesting(false)
                                    }
                                }

                            Text("\(content.count)/\(characterLimit)")
                                .font(.caption)
                                .foregroundStyle(content.count >= characterLimit ? Color.orange : Color.secondary)
                        }

                        if !selectedImages.isEmpty {
                            selectedImagesGrid
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        audienceRow

                        mediaToolbar

                        if isPreparingPhoto {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Подготавливаем фото…")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(18)
                }
            }
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
            .alert("Не удалось опубликовать", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task { await preparePhotos(newItems) }
        }
        .onChange(of: content) { _, newValue in
            if newValue.count > characterLimit {
                content = String(newValue.prefix(characterLimit))
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Отмена") {
                dismiss()
            }
            .foregroundStyle(.white)

            Spacer()

            Text("Новый пост")
                .font(.system(size: 18, weight: .bold))

            Spacer()

            Button {
                Task { await publish() }
            } label: {
                if isPublishing {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 96, height: 38)
                        .background(.white)
                        .clipShape(Capsule())
                } else {
                    Text("Опубликовать")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(canPublish ? Color.white : Color.white.opacity(0.35))
                        .clipShape(Capsule())
                }
            }
            .disabled(!canPublish || isPublishing || isPreparingPhoto)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
    }

    private var authorRow: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(liveSession.currentUser?.displayName ?? liveSession.currentUser?.username ?? "Unixgram")
                    .font(.system(size: 16, weight: .bold))

                if let username = liveSession.currentUser?.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var audienceRow: some View {
        HStack {
            Image(systemName: "globe.europe.africa")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Публикация")
                    .font(.system(size: 15, weight: .semibold))
                Text("Обычный пост Unixgram")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mediaToolbar: some View {
        HStack(spacing: 24) {
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: nil, matching: .images) {
                VStack(spacing: 5) {
                    Image(systemName: selectedImages.isEmpty ? "photo.on.rectangle" : "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                    Text(selectedImages.isEmpty ? "Фото" : "\(selectedImages.count) фото")
                        .font(.caption2)
                }
                .foregroundStyle(selectedImages.isEmpty ? Color.secondary : Color.white)
            }

            disabledTool("video", title: "Видео")
            disabledTool("music.note", title: "Музыка")
            disabledTool("chart.bar", title: "Опрос")
            disabledTool("star", title: "Stars")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var selectedImagesGrid: some View {
        LazyVGrid(
            columns: selectedImages.count == 1
                ? [GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(Array(selectedImages.enumerated()), id: \.element.id) { index, prepared in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: prepared.preview)
                        .resizable()
                        .scaledToFill()
                        .frame(height: selectedImages.count == 1 ? 280 : 155)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .background(Color.white.opacity(0.025))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        removeImage(at: index)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(.black.opacity(0.68))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            }
        }
    }

    private func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        if selectedPhotoItems.indices.contains(index) {
            selectedPhotoItems.remove(at: index)
        }
    }

    private func disabledTool(_ icon: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .opacity(0.55)
    }

    private var canPublish: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty
    }

    private var characterLimit: Int {
        liveSession.currentUser?.premium == true ? 1250 : 250
    }

    @ViewBuilder
    private var avatar: some View {
        if let raw = liveSession.currentUser?.avatarUrl,
           let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle().fill(Color.white.opacity(0.08))
                }
            }
        } else {
            Circle().fill(Color.white.opacity(0.08))
        }
    }

    @MainActor
    private func preparePhotos(_ items: [PhotosPickerItem]) async {
        isPreparingPhoto = true
        defer { isPreparingPhoto = false }

        guard !items.isEmpty else {
            selectedImages = []
            return
        }

        do {
            var prepared: [PreparedPostImage] = []
            prepared.reserveCapacity(items.count)

            for item in items {
                guard let originalData = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: originalData),
                      let jpegData = image.jpegData(compressionQuality: 0.92) else {
                    throw UnixgramCreatePostError.invalidImage
                }

                prepared.append(PreparedPostImage(data: jpegData, preview: image))
            }

            selectedImages = prepared
        } catch {
            selectedPhotoItems = []
            selectedImages = []
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish() async {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selectedImages.isEmpty else { return }

        isPublishing = true
        defer { isPublishing = false }

        do {
            var uploadedImages: [UnixgramRealAPIClient.UploadedPostMedia] = []
            uploadedImages.reserveCapacity(selectedImages.count)

            for (index, prepared) in selectedImages.enumerated() {
                let uploaded = try await UnixgramRealAPIClient.shared.uploadPostImage(
                    data: prepared.data,
                    filename: "ios-post-\(index + 1)-\(UUID().uuidString.lowercased()).jpg",
                    mimeType: "image/jpeg"
                )
                uploadedImages.append(uploaded)
            }

            _ = try await UnixgramRealAPIClient.shared.createPost(
                content: text,
                uploadedImages: uploadedImages
            )

            await dashboard.refreshFeed()
            onPublished?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PreparedPostImage: Identifiable {
    let id = UUID()
    let data: Data
    let preview: UIImage
}

private enum UnixgramCreatePostError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Не удалось подготовить выбранное фото"
        }
    }
}
