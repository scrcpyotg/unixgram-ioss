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

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImagePreview: UIImage?
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

                        if let image = selectedImagePreview {
                            selectedImageCard(image)
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
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await preparePhoto(newItem) }
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
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                VStack(spacing: 5) {
                    Image(systemName: selectedImageData == nil ? "photo" : "photo.fill")
                        .font(.system(size: 20))
                    Text("Фото")
                        .font(.caption2)
                }
                .foregroundStyle(selectedImageData == nil ? Color.secondary : Color.white)
            }

            disabledTool("video", title: "Видео")
            disabledTool("music.note", title: "Музыка")
            disabledTool("chart.bar", title: "Опрос")
            disabledTool("star", title: "Stars")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func selectedImageCard(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Button {
                selectedPhotoItem = nil
                selectedImageData = nil
                selectedImagePreview = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.68))
                    .clipShape(Circle())
            }
            .padding(10)
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
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
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
    private func preparePhoto(_ item: PhotosPickerItem) async {
        isPreparingPhoto = true
        defer { isPreparingPhoto = false }

        do {
            guard let originalData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: originalData),
                  let jpegData = image.jpegData(compressionQuality: 0.92) else {
                throw UnixgramCreatePostError.invalidImage
            }

            selectedImagePreview = image
            selectedImageData = jpegData
        } catch {
            selectedPhotoItem = nil
            selectedImageData = nil
            selectedImagePreview = nil
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish() async {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImageData != nil else { return }

        isPublishing = true
        defer { isPublishing = false }

        do {
            var uploadedImage: UnixgramRealAPIClient.UploadedPostMedia?

            if let imageData = selectedImageData {
                uploadedImage = try await UnixgramRealAPIClient.shared.uploadPostImage(
                    data: imageData,
                    filename: "ios-post-\(UUID().uuidString.lowercased()).jpg",
                    mimeType: "image/jpeg"
                )
            }

            _ = try await UnixgramRealAPIClient.shared.createPost(
                content: text,
                uploadedImage: uploadedImage
            )

            await dashboard.refreshFeed()
            onPublished?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
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
