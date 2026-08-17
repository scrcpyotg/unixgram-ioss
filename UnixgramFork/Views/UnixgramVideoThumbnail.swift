import SwiftUI
import AVFoundation
import UIKit

/// Generates and caches a real first-frame preview for Unixgram video posts.
/// This avoids the old empty gray rectangle with only a play icon.
struct UnixgramVideoThumbnailView: View {
    let videoURL: URL
    var cornerRadius: CGFloat = 14
    var showsPlayIcon: Bool = true

    @State private var frame: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let frame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        if !didFail {
                            ProgressView()
                                .tint(.white)
                        }
                    }
            }

            if showsPlayIcon {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: videoURL) {
            if let cached = UnixgramVideoFrameCache.shared.object(forKey: videoURL as NSURL) {
                frame = cached
                return
            }

            let generated = await UnixgramVideoFrameGenerator.makeFrame(url: videoURL)
            guard !Task.isCancelled else { return }

            if let generated {
                UnixgramVideoFrameCache.shared.setObject(generated, forKey: videoURL as NSURL)
                frame = generated
            } else {
                didFail = true
            }
        }
    }
}

private final class UnixgramVideoFrameCache {
    static let shared = NSCache<NSURL, UIImage>()
}

private enum UnixgramVideoFrameGenerator {
    static func makeFrame(url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 1200, height: 1200)
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)

                let candidateTimes = [
                    CMTime(seconds: 0.15, preferredTimescale: 600),
                    CMTime(seconds: 0.5, preferredTimescale: 600),
                    CMTime.zero
                ]

                for time in candidateTimes {
                    if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                        return
                    }
                }

                continuation.resume(returning: nil)
            }
        }
    }
}
