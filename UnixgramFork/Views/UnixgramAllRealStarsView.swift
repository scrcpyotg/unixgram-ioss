import SwiftUI

struct UnixgramAllRealStarsView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.yellow)
                    .padding(.top, 30)

                Text("Stars и подарки")
                    .font(.system(size: 32, weight: .bold))

                Text("Аккаунт: @\(liveSession.currentUser?.username ?? "")")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    infoCard("Premium", liveSession.currentUser?.premium == true ? "Да" : "Нет", "sparkles")
                    infoCard("Профиль", liveSession.currentUser?.isActive == true ? "Активен" : "Нет", "person.crop.circle")
                }

                Text("HAR подтверждает realtime-событие `stars:balance`, но не содержит HTTP endpoint первоначального баланса или отправки подарка. Поэтому баланс и покупки не выдумываются. Как только поймаем запрос Stars/Gifts из web — этот экран уже подключён к общей сессии и его можно сразу довести до полного real mode.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(18)
        }
        .background(Color.black)
    }

    private func infoCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
