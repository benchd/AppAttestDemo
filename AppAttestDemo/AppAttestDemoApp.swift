//
//  AppAttestDemoApp.swift
//  AppAttestDemo
//
//  Created by David Bench on 10/24/25.
//

import SwiftUI

@main
struct AppAttestDemoApp: App {
    // Shared AppAttestClient instance
    @StateObject private var client = AppAttestClient.shared
    
    var body: some Scene {
        WindowGroup {
            AppAttestView()
                .environmentObject(client)
                .task {
                    // Preload any required setup for App Attest
                    await client.initializeIfNeeded()
                }
        }
    }
}

