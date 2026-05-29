import Foundation
import FirebaseAuth
import AuthenticationServices

@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init() {
        addAuthStateListener()
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    private func addAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    // MARK: - Error Sanitization

    /// Convert Firebase AuthErrorCode to a user-facing message that doesn't leak sensitive details.
    /// Merges wrongPassword/userNotFound to prevent account enumeration.
    private func userFacingMessage(from error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return "An unexpected error occurred. Please try again."
        }

        switch code {
        case .wrongPassword, .userNotFound, .invalidCredential:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "This email is already in use."
        case .weakPassword:
            return "Password is too weak. Please use at least 6 characters."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .userDisabled:
            return "This account has been disabled."
        default:
            return "An unexpected error occurred. Please try again."
        }
    }

    // MARK: - Email/Password Auth

    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            user = result.user
            isAuthenticated = true
        } catch {
            errorMessage = userFacingMessage(from: error)
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            user = result.user
            isAuthenticated = true
        } catch {
            errorMessage = userFacingMessage(from: error)
            throw error
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        user = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            user = result.user
            isAuthenticated = true
        } catch {
            errorMessage = userFacingMessage(from: error)
            throw error
        }
    }

    // MARK: - Anonymous Auth (for testing without account)

    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signInAnonymously()
            user = result.user
            isAuthenticated = true
        } catch {
            errorMessage = userFacingMessage(from: error)
            throw error
        }
    }

    var currentUserId: String? {
        user?.uid
    }
}

enum AuthError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credential"
        }
    }
}

// MARK: - Apple Sign In Helpers

/// Generate a cryptographically random nonce using rejection sampling to avoid modulo bias.
func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let charsetCount = charset.count
    // Rejection sampling threshold to eliminate modulo bias
    let maxAllowed = (256 / charsetCount) * charsetCount

    var nonce = [Character]()
    nonce.reserveCapacity(length)

    while nonce.count < length {
        var randomByte: UInt8 = 0
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        // Reject bytes that would cause modulo bias
        if Int(randomByte) < maxAllowed {
            nonce.append(charset[Int(randomByte) % charsetCount])
        }
    }

    return String(nonce)
}

import CryptoKit

func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
    }.joined()
    return hashString
}
