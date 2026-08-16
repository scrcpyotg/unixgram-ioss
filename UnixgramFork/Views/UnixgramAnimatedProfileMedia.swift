import SwiftUI
import AVFoundation
import ImageIO

struct UnixgramAnimatedProfileMedia: View {
    let rawURL: String?
    var contentMode: ContentMode = .fill
    var muted: Bool = true

    var body: some View {
        Group {
            if let rawURL, let url = URL(string: rawURL) {
                if Self.isVideo(url) {
                    UGLoopingRemoteVideo(url: url, muted: muted)
                } else {
                    UGRemoteAnimatedImage(url: url, contentMode: contentMode)
                }
            } else {
                Color.white.opacity(0.04)
            }
        }
    }

    static func isVideo(_ url: URL) -> Bool {
        ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }
}

private struct UGRemoteAnimatedImage: UIViewRepresentable {
    let url: URL
    let contentMode: ContentMode

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.clipsToBounds = true
        view.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        context.coordinator.load(url: url, into: view)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        context.coordinator.load(url: url, into: uiView)
    }

    final class Coordinator {
        private var currentURL: URL?
        private var task: URLSessionDataTask?

        func load(url: URL, into view: UIImageView) {
            guard currentURL != url else { return }
            currentURL = url
            task?.cancel()
            task = URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data else { return }
                let image = Self.animatedImage(data: data)
                DispatchQueue.main.async {
                    guard self.currentURL == url else { return }
                    view.image = image
                }
            }
            task?.resume()
        }

        private static func animatedImage(data: Data) -> UIImage? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return UIImage(data: data) }
            let count = CGImageSourceGetCount(source)
            guard count > 1 else { return UIImage(data: data) }
            var frames: [UIImage] = []
            var duration: Double = 0
            for index in 0..<count {
                guard let cg = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
                let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                var frameDuration = 0.1
                if let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    frameDuration = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                        ?? (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
                }
                if frameDuration < 0.02 { frameDuration = 0.1 }
                duration += frameDuration
                frames.append(UIImage(cgImage: cg))
            }
            return UIImage.animatedImage(with: frames, duration: max(duration, 0.1)) ?? UIImage(data: data)
        }
    }
}

private struct UGLoopingRemoteVideo: UIViewRepresentable {
    let url: URL
    let muted: Bool

    func makeUIView(context: Context) -> LoopingVideoView {
        let view = LoopingVideoView()
        view.set(url: url, muted: muted)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoView, context: Context) {
        uiView.set(url: url, muted: muted)
    }
}

private final class LoopingVideoView: UIView {
    private let player = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func set(url: URL, muted: Bool) {
        player.isMuted = muted
        guard currentURL != url else { return }
        currentURL = url
        looper = nil
        player.removeAllItems()
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }
}
