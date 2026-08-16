import SwiftUI

struct FeatureHubView: View {
    var body: some View {
        List {
            Section("REAL API v0.10") {
                NavigationLink {
                    UnixgramRealAccountView()
                } label: {
                    Label("Реальный аккаунт", systemImage: "person.crop.circle.fill")
                }

                NavigationLink {
                    UnixgramRealMessagesView()
                } label: {
                    Label("Реальные сообщения", systemImage: "message.fill")
                }
            }

            Section("Unixgram iOS v0.9") {
                NavigationLink {
                    RealChatView(conversation: UGMockData.conversation)
                } label: {
                    Label("Реальный экран чата", systemImage: "bubble.left.and.bubble.right.fill")
                }

                NavigationLink {
                    StoriesExperienceView()
                } label: {
                    Label("Stories", systemImage: "circle.dashed.inset.filled")
                }

                NavigationLink {
                    GiftsStarsView()
                } label: {
                    Label("Stars и подарки", systemImage: "gift.fill")
                }

                NavigationLink {
                    PremiumView()
                } label: {
                    Label("Unix Premium", systemImage: "sparkles")
                }

                NavigationLink {
                    UnixgramConnectionStatusView()
                } label: {
                    Label("API / UnixProto", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Новые функции")
    }
}

private struct UnixgramConnectionStatusView: View {
    @StateObject private var realtime = UnixgramRealtimeStore()
    @State private var csrfStatus = "Не проверен"
    @State private var protoStatus = "Не инициализирован"

    var body: some View {
        List {
            Section("HTTP API") {
                HStack {
                    Text("CSRF")
                    Spacer()
                    Text(csrfStatus)
                        .foregroundStyle(.secondary)
                }

                Button("Получить CSRF token") {
                    Task {
                        do {
                            try await UnixgramGateway.shared.bootstrapCSRF()
                            csrfStatus = "Получен"
                        } catch {
                            csrfStatus = "Ошибка"
                        }
                    }
                }
            }

            Section("Realtime") {
                HStack {
                    Text("SSE")
                    Spacer()
                    Text(realtime.isConnected ? "Подключено" : "Отключено")
                        .foregroundStyle(realtime.isConnected ? .green : .secondary)
                }

                if let event = realtime.lastEventName {
                    LabeledContent("Последнее событие", value: event)
                }

                Button(realtime.isConnected ? "Отключить" : "Подключить") {
                    if realtime.isConnected {
                        realtime.disconnect()
                    } else {
                        realtime.connect()
                    }
                }
            }

            Section("UnixProto") {
                HStack {
                    Text("Native transport")
                    Spacer()
                    Text(protoStatus)
                        .foregroundStyle(.secondary)
                }

                Button("Подготовить transport") {
                    Task {
                        let transport = UnixProtoNativeTransport()
                        await transport.prepare()
                        protoStatus = "Ждёт официальные gateway constants"
                    }
                }

                Text("Неизвестные endpoint'ы, gateway host/port, закрытые ключи и методы не выдумываются. Пока подключены только публично описанные части Unixgram.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("API / UnixProto")
    }
}
