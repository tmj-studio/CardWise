import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var currentNonce: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo / brand header
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.heroGradient)
                            .frame(width: 80, height: 80)
                            .softShadow()

                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                    }

                    Text(Brand.displayName)
                        .font(.app(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Maximize your credit card rewards")
                        .font(.app(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                               let nonce = currentNonce {
                                Task {
                                    try? await authService.signInWithApple(credential: appleIDCredential, nonce: nonce)
                                }
                            }
                        case .failure:
                            break
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Theme.separator)
                            .frame(height: 1)
                        Text("or")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                        Rectangle()
                            .fill(Theme.separator)
                            .frame(height: 1)
                    }

                    // Email/Password
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .font(.app(.body))
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(14)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))

                        SecureField("Password", text: $password)
                            .font(.app(.body))
                            .textContentType(isSignUp ? .newPassword : .password)
                            .padding(14)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))

                        Button {
                            Task {
                                if isSignUp {
                                    try? await authService.signUp(email: email, password: password)
                                } else {
                                    try? await authService.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            Text(isSignUp ? "Create Account" : "Sign In")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(email.isEmpty || password.count < 6)

                        Button {
                            isSignUp.toggle()
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.app(.caption))
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    // Skip (Anonymous)
                    Button {
                        Task {
                            try? await authService.signInAnonymously()
                        }
                    } label: {
                        Text("Continue without account")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal)

                // Error message
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.app(.caption))
                        .foregroundStyle(Theme.danger)
                        .padding()
                }

                Spacer()
            }
            .padding()
            .screenBackground()
            .overlay {
                if authService.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService())
}
