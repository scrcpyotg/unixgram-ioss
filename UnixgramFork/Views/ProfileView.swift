import SwiftUI

struct ProfileView: View {
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    LinearGradient(
                        colors: [Color.brown.opacity(0.5), Color.gray.opacity(0.18), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 300)
                    .overlay {
                        Text("LIGHT\nTRIAD")
                            .font(.system(size: 44, weight: .light, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    HStack {
                        ProfileCircleButton(icon: "chevron.left")
                        Spacer()
                        ProfileCircleButton(icon: "circle.fill")
                        ProfileCircleButton(icon: "qrcode")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 122, height: 122)
                                .overlay(Image(systemName: "scribble.variable").font(.system(size: 52)))
                            Circle()
                                .fill(.green)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(.black, lineWidth: 4))
                        }

                        Spacer()

                        Button("Редактировать") { showSettings = true }
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 22)
                            .frame(height: 50)
                            .background(Color.black)
                            .overlay(Capsule().stroke(Color.white.opacity(0.14)))
                            .clipShape(Capsule())

                        ProfileCircleButton(icon: "sparkles")
                        ProfileCircleButton(icon: "gift")
                    }
                    .offset(y: -58)
                    .padding(.bottom, -58)

                    HStack(spacing: 8) {
                        Text("aeternaldeV")
                            .font(.system(size: 27, weight: .bold))
                        Image(systemName: "seal")
                            .foregroundStyle(.secondary)
                        Text("◉ 1")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(UGTheme.surface2)
                            .clipShape(Capsule())
                    }

                    Text("@aeternal")
                        .font(.system(size: 21))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Circle().fill(.green).frame(width: 10, height: 10)
                        Text("В сети").foregroundStyle(.green)
                    }
                    .font(.system(size: 19))

                    Text("а также ")
                        .foregroundStyle(.white)
                    + Text("@aeternaldeV, @regret, @vivid, @exg888,\n@aloha, @akiko, @elio, @velvet, @soulless,\n@doomed")
                        .foregroundStyle(UGTheme.blue)

                    HStack(spacing: 12) {
                        BadgeGlyph(text: "1", tint: .gray)
                        BadgeGlyph(text: "◆", tint: .purple)
                        BadgeGlyph(text: "❄", tint: .cyan)
                        BadgeGlyph(text: "♘", tint: .purple)
                    }
                    .padding(.vertical, 4)

                    metadata("location", "munhem")
                    metadata("link", "aeternal.space/")
                    metadata("calendar", "На Unixgram с 16 авг. 2026 г.")

                    HStack(spacing: 28) {
                        Text("0 ").bold() + Text("Подписки").foregroundStyle(.secondary)
                        Text("2 ").bold() + Text("Подписчики").foregroundStyle(.secondary)
                    }
                    .font(.system(size: 20))

                    HStack(spacing: 10) {
                        Text("КАНАЛ")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("1 подписчик")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.top, 4)

                    HStack(spacing: 14) {
                        Circle()
                            .fill(LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 62, height: 62)
                            .overlay(Text("↳").font(.title2.bold()))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("aeternal").font(.system(size: 19, weight: .bold))
                            Text("Пока нет публикаций").foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(UGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                    HStack {
                        Image(systemName: "play.fill")
                        Text("🌐 Janina - Terranova")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("Изменить ›")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(UGTheme.surface)

                    HStack(spacing: 12) {
                        Circle()
                            .stroke(Color.white.opacity(0.14))
                            .frame(width: 64, height: 64)
                            .overlay(Image(systemName: "plus").font(.title3))
                        Text("Новый")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .background(Color.black)
        .sheet(isPresented: $showSettings) {
            ProfileSettingsSheet(isPresented: $showSettings)
                .presentationDetents([.fraction(0.82), .large])
                .presentationDragIndicator(.hidden)
                .unixgramPresentationCornerRadius(30)
                .unixgramClearPresentationBackground()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func metadata(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(title).foregroundStyle(.secondary)
        }
        .font(.system(size: 18))
    }
}

private struct ProfileCircleButton: View {
    let icon: String

    var body: some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.62))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12)))
        }
    }
}

private struct BadgeGlyph: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
