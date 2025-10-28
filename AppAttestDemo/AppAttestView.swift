//
//  AppAttestView.swift
//  AppAttestDemo
//
//  Updated to include Secure API verification
//

import SwiftUI

struct AppAttestView: View {
    @StateObject private var client = AppAttestClient.shared
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                Text("🔒 Apple App Attest Demo")
                    .font(.title2)
                    .bold()

                Text(client.statusMessage)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let jwt = client.jwtToken {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("✅ Verified successfully")
                                .font(.headline)
                            Text("JWT Token:")
                                .font(.subheadline)
                            Text(jwt)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // --- Secure API button ---
                    Button {
                        Task {
                            await verifySecureAPI()
                        }
                    } label: {
                        Label("Verify Secure API", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    // --- Smart Secure Request button ---
                    Button {
                        Task {
                            await smartSecureRequest()
                        }
                    } label: {
                        Label("Send Secure Request", systemImage: "arrow.clockwise.circle.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                }

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }

                Button {
                    Task {
                        await runAttestation()
                    }
                } label: {
                    Label("Run App Attest", systemImage: "key.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding(.horizontal)
                
                // --- Smart Secure Request button (always visible) ---
                Button {
                    Task {
                        await smartSecureRequest()
                    }
                } label: {
                    Label("Send Secure Request", systemImage: "arrow.clockwise.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding(.horizontal)
                
                // --- Sign Up Without Device Code button ---
                NavigationLink(destination: SignUpView()) {
                    Label("Sign Up Without Device Code", systemImage: "person.badge.plus")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("App Attest")
        }
        .task {
            await client.initializeIfNeeded()
        }
    }

    // MARK: - Run Attestation
    private func runAttestation() async {
        isLoading = true
        defer { isLoading = false }

        await client.runFullAttestationFlow()
    }

    // MARK: - Verify Secure API
    private func verifySecureAPI() async {
        isLoading = true
        defer { isLoading = false }

        await client.callSecureEndpoint()
    }
    
    // MARK: - Smart Secure Request
    private func smartSecureRequest() async {
        isLoading = true
        defer { isLoading = false }

        await client.smartSecureRequest()
    }
}
