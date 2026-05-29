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

                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("SmartCard")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Maximize your credit card rewards")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }

                    // Email/Password
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isSignUp ? .newPassword : .password)

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
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty || password.count < 6)

                        Button {
                            isSignUp.toggle()
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.caption)
                        }
                    }

                    // Skip (Anonymous)
                    Button {
                        Task {
                            try? await authService.signInAnonymously()
                        }
                    } label: {
                        Text("Continue without account")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Error message
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }

                Spacer()
            }
            .padding()
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
