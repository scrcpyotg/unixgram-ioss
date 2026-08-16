import SwiftUI

struct UnixgramAllRealPremiumView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(.purple)
                    .padding(.top, 30)

                Text("Unix Premium")
                    .font(.system(size: 34, weight: .bold))

                Text(liveSession.currentUser?.premium == true ? "Premium активен на вашем аккаунте" : "Premium не активен")
                    .foregroundStyle(liveSession.currentUser?.premium == true ? Color.green : Color.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        row("Аккаунт", "@\(liveSession.currentUser?.username ?? "")")
                        row("Статус", liveSession.currentUser?.premium == true ? "Premium" : "Обычный")
                        row("Регистрация", liveSession.currentUser?.registrationNumber.map { "#\($0)" } ?? "—")
                    }
                }
                .groupBoxStyle(.automatic)

                Text("В текущем HAR нет endpoint покупки/тарифов Premium. Поэтому экран использует реальный Premium status из `/api/auth/me`, но не делает фиктивную оплату.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(18)
        }
        .background(Color.black)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }
}
