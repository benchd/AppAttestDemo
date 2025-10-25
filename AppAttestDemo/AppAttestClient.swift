//
//  AppAttestClient.swift
//  AppAttestDemo
//
//  Updated for ObservableObject and correct Base64 challenge handling
//

import Foundation
import DeviceCheck
import Combine
import CryptoKit

@MainActor
final class AppAttestClient: ObservableObject {
    static let shared = AppAttestClient()

    @Published var statusMessage: String = ""
    @Published var jwtToken: String? = nil
    @Published var isAttested: Bool = false

    private let service = DCAppAttestService.shared
    private let serverBaseURL = URL(string: "https://ss.myprohelper.com:6012/api/auth")!
    private var keyId: String?

    private init() {}

    // MARK: - Initialization
    func initializeIfNeeded() async {
        guard service.isSupported else {
            statusMessage = "App Attest not supported on this device."
            return
        }

        statusMessage = "Initializing App Attest..."
        do {
            let storedKeyId = UserDefaults.standard.string(forKey: "AppAttestKeyId")
            if let keyId = storedKeyId {
                self.keyId = keyId
                statusMessage = "Existing App Attest key found ✅"
            } else {
                let newKeyId = try await service.generateKey()
                self.keyId = newKeyId
                UserDefaults.standard.set(newKeyId, forKey: "AppAttestKeyId")
                statusMessage = "Generated new App Attest key ✅"
            }
        } catch {
            statusMessage = "Failed to initialize App Attest: \(error.localizedDescription)"
        }
    }

    // MARK: - Full attestation flow
    func runFullAttestationFlow() async {
        statusMessage = "Fetching challenge..."
        do {
            let challenge = try await fetchChallenge()

            guard service.isSupported else {
                throw NSError(domain: "AppAttest", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "App Attest not supported on this device"])
            }

            // Generate or reuse key
            let keyId = try await service.generateKey()
            self.keyId = keyId

            // Correct Base64 decode before SHA256
            guard let challengeData = Data(base64Encoded: challenge) else {
                throw NSError(domain: "AppAttest", code: -10,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid Base64 challenge"])
            }

            let clientDataHash = Data(SHA256.hash(data: challengeData))
            print("ClientDataHash (Base64): \(clientDataHash.base64EncodedString())")

            statusMessage = "Generating attestation..."
            let attestation = try await withTimeout(seconds: 20) { [self] in
                try await service.attestKey(keyId, clientDataHash: clientDataHash)
            }

            statusMessage = "Sending attestation to server..."
            let jwt = try await sendAttestation(
                keyId: keyId,
                attestationObject: attestation,
                challenge: challenge
            )

            self.jwtToken = jwt
            statusMessage = "✅ Attestation successful"
        } catch {
            statusMessage = "❌ Attestation failed: \(error.localizedDescription) (\(error))"
        }
    }

    // MARK: - Timeout Helper
    func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Step 1: Fetch challenge
    func fetchChallenge() async throws -> String {
        let url = serverBaseURL.appendingPathComponent("challenge")
        
        // Create a custom URLSession configuration that doesn't follow redirects
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AppAttest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        // Handle redirect manually - if we get a 307, try the original port 6012 directly
        if httpResponse.statusCode == 307 {
            print("Received redirect, trying direct connection to port 6012...")
            // Try the challenge endpoint directly on port 6012 without redirect
            let directURL = URL(string: "https://ss.myprohelper.com:6012/api/auth/challenge")!
            let (directData, directResponse) = try await session.data(from: directURL)
            guard let directHttpResponse = directResponse as? HTTPURLResponse, directHttpResponse.statusCode == 200 else {
                throw NSError(domain: "AppAttest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response after redirect handling"])
            }
            
            let challengeResponse = try JSONDecoder().decode([String: String].self, from: directData)
            guard let challenge = challengeResponse["challenge"] else {
                throw NSError(domain: "AppAttest", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing challenge"])
            }
            print("Fetched challenge: \(challenge)")
            return challenge
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AppAttest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        let challengeResponse = try JSONDecoder().decode([String: String].self, from: data)
        guard let challenge = challengeResponse["challenge"] else {
            throw NSError(domain: "AppAttest", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing challenge"])
        }
        print("Fetched challenge: \(challenge)")
        return challenge
    }

    // MARK: - Step 2: Send attestation
    private func sendAttestation(keyId: String, attestationObject: Data, challenge: String) async throws -> String {
        let url = serverBaseURL.appendingPathComponent("attest")
        let payload: [String: Any] = [
            "keyId": keyId,
            "attestationObject": attestationObject.base64EncodedString(),
            "challenge": challenge
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AppAttest", code: -3, userInfo: [NSLocalizedDescriptionKey: "No server response"])
        }

        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let jwt = json?["jwt"] as? String {
                print("✅ JWT received: \(jwt.prefix(40))...")
                return jwt
            } else {
                throw NSError(domain: "AppAttest", code: -4, userInfo: [NSLocalizedDescriptionKey: "JWT missing in response"])
            }
        } else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Server error: \(errorText)")
            throw NSError(domain: "AppAttest", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorText])
        }
    }
}

extension AppAttestClient {
    // MARK: - Step 3: Call a protected endpoint using the JWT
    func callSecureEndpoint() async {
        guard let jwt = jwtToken else {
            statusMessage = "❌ No JWT available. Please attest first."
            return
        }

        let url = serverBaseURL.appendingPathComponent("../securedata/info").standardized

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("✅ Secure response: \(json ?? [:])")
                statusMessage = "✅ Secure endpoint call succeeded!"
            } else {
                let text = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Secure endpoint error: \(text)")
                statusMessage = "❌ Secure endpoint failed (\(httpResponse.statusCode))"
            }
        } catch {
            statusMessage = "❌ Network error: \(error.localizedDescription)"
        }
    }
}
