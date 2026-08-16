import SwiftUI

struct GiftsStarsView: View {
    enum Mode {
        case full
        case picker
    }

    var mode: Mode = .full

    @Environment(\.dismiss) private var dismiss
    @State private var balance = 0
    @State private var selectedGift: UGGift?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    balanceCard

                    HStack {
                        Text("Подарки")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                        if mode == .full {
                            Button("История") {}
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(UGMockData.gifts) { gift in
                            Button {
                                selectedGift = gift
                            } label: {
                                VStack(spacing: 10) {
                                    Text(gift.emoji)
                                        .font(.system(size: 66))

                                    Text(gift.title)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white)

                                    Label("\(gift.price)", systemImage: "star.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.yellow)

                                    Text(gift.rarity)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 180)
                                .background(Color.white.opacity(0.035))
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10)))
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.black)
            .navigationTitle(mode == .picker ? "Отправить подарок" : "Stars и подарки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode == .picker {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { dismiss() }
                    }
                }
            }
            .sheet(item: $selectedGift) { gift in
                GiftDetailSheet(gift: gift, balance: $balance)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(28)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var balanceCard: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 84)
                .overlay(Image(systemName: "star.fill").font(.system(size: 36)).foregroundStyle(.white))

            Text("\(balance)")
                .font(.system(size: 52, weight: .bold))

            Text("звёзд на балансе")
                .foregroundStyle(.secondary)

            Button("Пополнить") {}
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .frame(height: 44)
                .background(.white)
                .clipShape(Capsule())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.16), Color.white.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

private struct GiftDetailSheet: View {
    let gift: UGGift
    @Binding var balance: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 70, height: 5)

            Text(gift.emoji)
                .font(.system(size: 84))

            Text(gift.title)
                .font(.system(size: 25, weight: .bold))

            Text(gift.rarity)
                .foregroundStyle(.secondary)

            if let resaleValue = gift.resaleValue {
                Text("Получатель сможет добавить подарок в профиль или обменять его на \(resaleValue) звезды.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button {
                dismiss()
            } label: {
                Label("Отправить за \(gift.price)", systemImage: "star.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding(20)
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
        .preferredColorScheme(.dark)
    }
}
