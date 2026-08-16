import SwiftUI

struct UnixgramVerificationStatusView: View {
    @State private var request: UGVerificationRequest?
    @State private var loading = true
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Верификация")
                .font(.system(size: 24, weight: .bold))

            if loading {
                ProgressView("Проверяем статус…")
            } else if let request {
                HStack {
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.status ?? "Заявка")
                            .font(.headline)
                        if let reason = request.reason {
                            Text(reason).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            } else if loaded {
                Text("Активной заявки на верификацию нет.")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            request = try? await UnixgramRealAPIClient.shared.verificationRequest()
            loaded = true
            loading = false
        }
    }
}
