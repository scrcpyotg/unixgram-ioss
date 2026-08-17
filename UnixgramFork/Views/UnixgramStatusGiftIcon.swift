import SwiftUI

/// Small status/pinned gift rendered next to a Unixgram display name.
struct UnixgramStatusGiftIcon: View {
    let gift: UGProfileGift
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let raw = gift.modelPngUrl ?? gift.templateImageUrl,
               let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(gift.title ?? "Статусный подарок")
    }

    private var fallback: some View {
        Image(systemName: "gift.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.purple)
            .padding(size * 0.12)
    }
}
