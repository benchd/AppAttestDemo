//
//  SettingsView.swift
//  AppAttestDemo
//
//  Created by David Bench on 10/24/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("baseURL") private var baseURL: String = "https://ss.myprohelper.com:6012/api"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Base URL")) {
                    TextField("https://...", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Reset to Default") { baseURL = "https://ss.myprohelper.com:6012/api" }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
