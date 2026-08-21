import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Native implementation of Unixgram's real web "Поддержать звёздами" flow.
///
/// Captured web behavior:
/// - endpoint: POST /api/social/posts/{postId}/donate
/// - presets: 10 / 50 / 100 / 500 / 1000
/// - custom amount: 1...1_000_000
/// - optional message: up to 200 characters
/// - response: amount + donorBalance
struct UnixgramPostStarsSupportSheet: View {
    let post: UGHARFeedPost

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @StateObject private var commerce = UnixgramCommerceStore.shared

    @State private var amount = 50
    @State private var customAmountText = "50"
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private let presets = [10, 50, 100, 500, 1_000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    amountDisplay
                    presetsGrid
                    customAmountField
                    messageField
                    balanceCard
                    sendButton
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Поддержать звёздами")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .disabled(isSending)
                }
            }
            .alert(
                "Не удалось отправить звёзды",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                await commerce.refreshStars(fallback: liveSession.currentUser)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: 54, height: 54)
                .background(Color.yellow.opacity(0.13))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Звёзды получит")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(authorName)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var amountDisplay: some View {
        HStack(spacing: 9) {
            Image(systemName: "star.fill")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.yellow)

            Text(formattedAmount)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var presetsGrid: some View {
        HStack(spacing: 7) {
            ForEach(presets, id: \.self) { value in
                Button {
                    setAmount(value)
                } label: {
                    Text(compactNumber(value))
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(amount == value ? Color.black : Color.white)
                        .background(
                            amount == value
                                ? Color.yellow
                                : Color.white.opacity(0.065)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    amount == value
                                        ? Color.yellow.opacity(0.7)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
    }

    private var customAmountField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Своё количество")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)

                TextField("1–1 000 000", text: $customAmountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .onChange(of: customAmountText) { newValue in
                        normalizeCustomAmount(newValue)
                    }

                if !customAmountText.isEmpty {
                    Button {
                        customAmountText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Сообщение")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(message.count)/200")
                    .font(.caption2)
                    .foregroundStyle(message.count >= 190 ? Color.orange : Color.secondary)
                    .monospacedDigit()
            }

            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text("Добавить сообщение (необязательно)…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 86, maxHeight: 110)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.clear)
                    .onChange(of: message) { newValue in
                        if newValue.count > 200 {
                            message = String(newValue.prefix(200))
                        }
                    }
            }
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var balanceCard: some View {
        HStack {
            Text("Ваш баланс")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer()

            if let balance = currentBalance {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(balance)")
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                }
            } else if commerce.isRefreshingStars {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sendButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await donate() }
            } label: {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "star.fill")
                    }

                    Text(isSending ? "Отправляем…" : "Поддержать \(formattedAmount) ⭐")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.black)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)

            if let balance = currentBalance, amount > balance {
                Text("Недостаточно звёзд: нужно \(amount), на балансе \(balance)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var currentBalance: Int? {
        commerce.starsBalance ?? liveSession.currentUser?.resolvedStarsBalance
    }

    private var canSend: Bool {
        guard !isSending, (1...1_000_000).contains(amount) else { return false }
        if let balance = currentBalance, amount > balance { return false }
        return true
    }

    private var authorName: String {
        post.author?.displayName
            ?? post.author?.username.map { "@\($0)" }
            ?? post.community?.name
            ?? "автор поста"
    }

    private var formattedAmount: String {
        Self.amountFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private func compactNumber(_ value: Int) -> String {
        switch value {
        case 1_000: return "1K"
        default: return "\(value)"
        }
    }

    private func setAmount(_ value: Int) {
        amount = value
        customAmountText = "\(value)"
    }

    private func normalizeCustomAmount(_ raw: String) {
        let digits = raw.filter(\.isNumber)

        if digits != raw {
            customAmountText = digits
            return
        }

        guard !digits.isEmpty else {
            amount = 0
            return
        }

        let parsed = Int(digits) ?? 0
        let clamped = min(1_000_000, max(1, parsed))

        amount = clamped

        if parsed != clamped {
            customAmountText = "\(clamped)"
        }
    }

    @MainActor
    private func donate() async {
        guard canSend else { return }

        isSending = true
        defer { isSending = false }

        do {
            let result = try await UnixgramRealAPIClient.shared.donateToPost(
                postId: post.id,
                amount: amount,
                message: message
            )

            commerce.applyConfirmedStarsBalance(result.donorBalance)

            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif

            dismiss()
        } catch {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            errorMessage = error.localizedDescription
        }
    }
}
