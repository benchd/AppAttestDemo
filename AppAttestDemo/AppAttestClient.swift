//
//  AppAttestClient.swift
//  AppAttestDemo
//
//  Created by David Bench on 10/24/25.
//

import Foundation
import DeviceCheck
import CryptoKit
import SwiftUI

struct ChallengeResponse: Codable { let challenge: String }
struct TokenResponse: Codable { let token: String }

final class AppAttestClient {
    private let service = DCAppAttestService.shared

    // Editable from SettingsView via @AppStorage
    @AppStorage("baseURL") private var storedBaseURL: String = "https://ss.myprohelper.com:6012/api"

    // Your server uses /api/auth/* routes
    private var baseAuthURL: URL { URL(string: storedBaseURL)!.appendingPathComponent("auth") }

    private(set) var keyId: String?

    func fetchChallenge() async throws -> Data {
        let url = baseAuthURL.appendingPathComponent("challenge")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoded = try JSONDecoder().decode(ChallengeResponse.self, from: data)
        guard let bytes = Data(base64Encoded: decoded.challenge) else {
            throw URLError(.cannotDecodeContentData)
        }
        return bytes
    }

    func generateAttestation(challenge: Data) async throws -> (keyId: String, attestation: Data) {
        guard service.isSupported else {
            throw NSError(domain: "AppAttest", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Attest not supported on this device"])
        }
        print("Bundle Identifier:", Bundle.main.bundleIdentifier ?? "nil")
        
        let keyId = try await service.generateKey()
        self.keyId = keyId
        let clientHash = Data(SHA256.hash(data: challenge))
        let attestation = try await service.attestKey(keyId, clientDataHash: clientHash)
        return (keyId, attestation)
    }

    func sendAttestation(_ keyId: String, _ attestation: Data, challenge: Data) async throws -> String {
        var req = URLRequest(url: baseAuthURL.appendingPathComponent("attest"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "keyId": keyId,
            "attestationObject": attestation.base64EncodedString(),
            "challenge": challenge.base64EncodedString()
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Server error"
            throw NSError(domain: "AppAttest", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        return token.token
    }

    func generateAssertion(challenge: Data) async throws -> Data {
        guard let keyId else {
            throw NSError(domain: "AppAttest", code: 3, userInfo: [NSLocalizedDescriptionKey: "No keyId. Run attestation first."])
        }
        let clientHash = Data(SHA256.hash(data: challenge))
        return try await service.generateAssertion(keyId, clientDataHash: clientHash)
    }

    func sendAssertion(_ assertion: Data, keyId: String, jwt: String, challenge: Data) async throws {
        var req = URLRequest(url: baseAuthURL.appendingPathComponent("assert"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + jwt, forHTTPHeaderField: "Authorization")
        let body: [String: String] = [
            "keyId": keyId,
            "assertion": assertion.base64EncodedString(),
            "challenge": challenge.base64EncodedString()
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
}
