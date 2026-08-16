import SwiftUI

struct PremiumView: View {
    @State private var selectedPlan = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                premiumHero

                VStack(spacing: 12) {
                    ForEach(UGMockData.premiumFeatures) { feature in
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(colors: [.purple.opacity(0.85), .blue.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 50, height: 50)
                                .overlay(Image(systemName: feature.icon).foregroundStyle(.white))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(feature.title)
                                    .font(.system(size: 18, weight: .bold))
                                Text(feature.subtitle)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }

                HStack(spacing: 12) {
                    planCard("1 месяц", "Premium", 0)
                    planCard("12 месяцев", "Выгоднее", 1)
                }

                Button {} label: {
                    Text("Подключить Unix Premium")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Text("Оплата и реальные тарифы будут подключены только после появления подтверждённого публичного метода Unixgram для Premium.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
        }
        .background(Color.black)
        .navigationTitle("Unix Premium")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var premiumHero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.purple, .blue, .cyan, .pink, .purple],
                            center: .center
                        )
                    )
                    .frame(width: 112, height: 112)

                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Unix Premium")
                .font(.system(size: 34, weight: .bold))

            Text("Больше возможностей и персонализации Unixgram")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }

    private func planCard(_ title: String, _ subtitle: String, _ index: Int) -> some View {
        Button {
            selectedPlan = index
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(index == 1 ? .yellow : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(selectedPlan == index ? Color.purple.opacity(0.16) : Color.white.opacity(0.035))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selectedPlan == index ? Color.purple : Color.white.opacity(0.10), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
