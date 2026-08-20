import SwiftUI
import AVKit
import Photos
import UIKit

struct UnixgramMediaViewerItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case image
        case video
    }

    let id = UUID()
    let url: URL
    let kind: Kind
}

struct UnixgramMediaViewer: View {
    let item: UnixgramMediaViewerItem

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch item.kind {
                case .image:
                    ZoomableRemoteImage(url: item.url)
                case .video:
                    videoPlayer
                }
            }
            .ignoresSafeArea(edges: .bottom)

            VStack {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 18, weight: .bold))
                            }
                        }
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                    .disabled(isSaving)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }

            if let saveMessage {
                VStack {
                    Spacer()
                    Text(saveMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private var videoPlayer: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
            } else {
                ProgressView()
                    .tint(.white)
                    .task {
                        let newPlayer = AVPlayer(url: item.url)
                        player = newPlayer
                        newPlayer.play()
                    }
            }
        }
    }

    @MainActor
    private func saveToPhotos() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let status = await requestAddOnlyPhotoPermission()
            guard status == .authorized || status == .limited else {
                throw MediaSaveError.photoAccessDenied
            }

            switch item.kind {
            case .image:
                let (data, response) = try await URLSession.shared.data(from: item.url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw MediaSaveError.downloadFailed
                }
                guard let image = UIImage(data: data) else {
                    throw MediaSaveError.invalidImage
                }
                try await saveImage(image)

            case .video:
                let (temporaryURL, response) = try await URLSession.shared.download(from: item.url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw MediaSaveError.downloadFailed
                }

                let extensionName = item.url.pathExtension.isEmpty ? "mp4" : item.url.pathExtension
                let localURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("unixgram-\(UUID().uuidString).\(extensionName)")
                try? FileManager.default.removeItem(at: localURL)
                try FileManager.default.moveItem(at: temporaryURL, to: localURL)
                defer { try? FileManager.default.removeItem(at: localURL) }
                try await saveVideo(at: localURL)
            }

            showSaveMessage("Сохранено в Фото")
        } catch {
            showSaveMessage(error.localizedDescription)
        }
    }

    @MainActor
    private func showSaveMessage(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            saveMessage = message
        }

        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if saveMessage == message {
                        saveMessage = nil
                    }
                }
            }
        }
    }
}

private struct ZoomableRemoteImage: View {
    let url: URL

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.2
                                    lastScale = 2.2
                                }
                            }
                        }
                case .failure:
                    UnixgramContentUnavailableView(
                        "Не удалось открыть фото",
                        systemImage: "photo.badge.exclamationmark"
                    )
                    .foregroundStyle(.white)
                default:
                    ProgressView().tint(.white)
                }
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                if scale <= 1.02 {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        scale = 1
                        offset = .zero
                    }
                }
                lastScale = scale
                lastOffset = offset
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}

private enum MediaSaveError: LocalizedError {
    case photoAccessDenied
    case downloadFailed
    case invalidImage
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "Разрешите Unixgram сохранять фото и видео в настройках iPhone"
        case .downloadFailed:
            return "Не удалось скачать файл"
        case .invalidImage:
            return "Не удалось прочитать изображение"
        case .saveFailed:
            return "Не удалось сохранить файл"
        }
    }
}

private func requestAddOnlyPhotoPermission() async -> PHAuthorizationStatus {
    await withCheckedContinuation { continuation in
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            continuation.resume(returning: status)
        }
    }
}

private func saveImage(_ image: UIImage) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if let error {
                continuation.resume(throwing: error)
            } else if success {
                continuation.resume(returning: ())
            } else {
                continuation.resume(throwing: MediaSaveError.saveFailed)
            }
        }
    }
}

private func saveVideo(at url: URL) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            if let error {
                continuation.resume(throwing: error)
            } else if success {
                continuation.resume(returning: ())
            } else {
                continuation.resume(throwing: MediaSaveError.saveFailed)
            }
        }
    }
}
