import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var revealPassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.055, green: 0.06, blue: 0.10))
                            .frame(width: 58, height: 58)
                        Text("ū")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Unixgram")
                        .font(.system(size: 31, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 82)

                Text("Регистрация")
                    .font(.system(size: 43, weight: .bold))
                    .padding(.top, 78)

                Text("Создайте аккаунт, чтобы начать")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(UGTheme.secondary)
                    .padding(.top, 20)

                fieldLabel("Email")
                    .padding(.top, 50)
                TextField("ilya@gmail.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 22)
                    .frame(height: 78)
                    .background(UGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(UGTheme.border))

                fieldLabel("Пароль")
                    .padding(.top, 28)

                HStack {
                    Group {
                        if revealPassword {
                            TextField("Пароль", text: $password)
                        } else {
                            SecureField("••••••••••", text: $password)
                        }
                    }
                    .textInputAutocapitalization(.never)

                    Button {
                        revealPassword.toggle()
                    } label: {
                        Image(systemName: revealPassword ? "eye.slash" : "eye")
                            .font(.system(size: 25))
                            .foregroundStyle(UGTheme.secondary)
                    }
                }
                .padding(.horizontal, 22)
                .frame(height: 78)
                .background(UGTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(UGTheme.border))

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        session.isAuthenticated = true
                    }
                } label: {
                    Text("Создать аккаунт")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .padding(.top, 34)

                HStack(spacing: 6) {
                    Text("Уже есть аккаунт?")
                        .foregroundStyle(UGTheme.secondary)
                    Button("Войти") {
                        session.isAuthenticated = true
                    }
                    .foregroundStyle(.white)
                }
                .font(.system(size: 20))
                .frame(maxWidth: .infinity)
                .padding(.top, 34)

                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("Онлайн")
                        .fontWeight(.bold)
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                }
                .foregroundStyle(Color(red: 0.48, green: 0.78, blue: 1.0))
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(Color(red: 0.02, green: 0.13, blue: 0.18))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.cyan.opacity(0.3)))
                .padding(.top, 34)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .background(UGTheme.bg)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 19, weight: .semibold))
            .padding(.bottom, 14)
    }
}
