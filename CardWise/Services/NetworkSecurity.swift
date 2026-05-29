import Foundation
import Security
import CryptoKit

/// Provides a URLSession with certificate pinning for Cloud Functions requests.
final class PinnedURLSession: NSObject, URLSessionDelegate {
    static let shared = PinnedURLSession()

    /// Pre-configured URLSession with certificate pinning enabled.
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Pinned domain suffix for Google Cloud Functions.
    private let pinnedDomainSuffix = ".cloudfunctions.net"

    private override init() {
        super.init()
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              challenge.protectionSpace.host.hasSuffix(pinnedDomainSuffix) else {
            // Not our pinned domain — let the system handle it
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Validate the server certificate chain
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If no pins are configured, fall back to standard TLS validation
        if Self.pinnedPublicKeyHashes.isEmpty {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        // Extract certificates from the chain
        let certificates: [SecCertificate]
        if #available(iOS 15.0, *) {
            guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
                  !chain.isEmpty else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            certificates = chain
        } else {
            let count = SecTrustGetCertificateCount(serverTrust)
            guard count > 0 else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            certificates = (0..<count).compactMap { SecTrustGetCertificateAtIndex(serverTrust, $0) }
        }

        // Check public key hash of each certificate in the chain against pinned hashes
        for cert in certificates {
            guard let publicKey = SecCertificateCopyKey(cert),
                  let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data else {
                continue
            }

            let keyHash = SHA256.hash(data: publicKeyData)
            let keyHashBase64 = Data(keyHash).base64EncodedString()

            if Self.pinnedPublicKeyHashes.contains(keyHashBase64) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // No pin matched
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    // MARK: - Pinned Hashes

    /// Base64-encoded SHA-256 hashes of the public keys to pin.
    /// Populate these with the actual SPKI hashes for your Cloud Functions domain.
    /// Generate with:
    ///   openssl s_client -connect us-central1-YOUR_PROJECT.cloudfunctions.net:443 </dev/null 2>/dev/null \
    ///     | openssl x509 -pubkey -noout \
    ///     | openssl pkey -pubin -outform DER \
    ///     | openssl dgst -sha256 -binary | base64
    ///
    /// Include at least 2 hashes (primary + backup) to allow rotation.
    static let pinnedPublicKeyHashes: Set<String> = [
        // Add your SPKI hashes here, e.g.:
        // "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        // "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
    ]
}
