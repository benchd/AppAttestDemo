//
//  AppAttestView.swift
//  AppAttestDemo
//
//  Created by David Bench on 10/24/25.
//

import SwiftUI
import DeviceCheck

struct AppAttestView: View {
    @State private var status: String = "Ready"
    @State private var token: String?
    @State private var keyId: String?
    @State private var isProcessing = false
    @State private var showSettings = false
    private let client = AppAttestClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("🔐 App Attest Demo").font(.title2).bold()
                Text(status).multilineTextAlignment(.center).font(.footnote).foregroundStyle(.secondary)

                if let token {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JWT").font(.caption).foregroundStyle(.secondary)
                        ScrollView {
                            Text(token).textSelection(.enabled).font(.caption.monospaced())
                        }
                        .frame(maxHeight: 120)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if isProcessing { ProgressView().padding(.bottom, 4) }

                HStack {
                    Button("Run Attestation") { Task { await runAttestation() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)

                    Button("Generate Assertion") { Task { await runAssertion() } }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing || token == nil)
                }

                Spacer()

                Text(currentBaseURL)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("App Attest")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var currentBaseURL: String {
        let url = UserDefaults.standard.string(forKey: "baseURL") ?? ""
        return url.isEmpty ? "(no base URL set)" : "Base URL: " + url
    }

    private func runAttestation() async {
        isProcessing = true; defer { isProcessing = false }
        do {
            status = "Requesting challenge…"
            let challenge = try await client.fetchChallenge()
            status = "Generating attestation…"
            let (keyId, att) = try await client.generateAttestation(challenge: challenge)
            self.keyId = keyId
            status = "Sending attestation…"
            let jwt = try await client.sendAttestation(keyId, att, challenge: challenge)
            self.token = jwt
            status = "✅ Attestation verified. JWT issued."
        } catch {
            status = "❌ " + (error.localizedDescription)
        }
    }

    private func runAssertion() async {
        guard let keyId, let token else { return }
        isProcessing = true; defer { isProcessing = false }
        do {
            status = "Fetching new challenge…"
            let challenge = try await client.fetchChallenge()
            status = "Generating assertion…"
            let assertion = try await client.generateAssertion(challenge: challenge)
            status = "Sending assertion…"
            try await client.sendAssertion(assertion, keyId: keyId, jwt: token, challenge: challenge)
            status = "✅ Assertion verified."
        } catch {
            status = "❌ " + (error.localizedDescription)
        }
    }
}

#Preview {
    AppAttestView()
}
