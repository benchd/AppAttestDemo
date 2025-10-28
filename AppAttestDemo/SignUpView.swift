//
//  SignUpView.swift
//  AppAttestDemo
//
//  Sign Up Without Device Code flow
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var client = AppAttestClient.shared
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var validationCode = ""
    @State private var phoneNumberGuid = ""
    @State private var currentStep = 1 // 1: Personal Info, 2: Phone Validation, 3: Email Validation, 4: Complete
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var codeValidationError = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: 4)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Step indicator
                        HStack {
                            ForEach(1...4, id: \.self) { step in
                                Circle()
                                    .fill(step <= currentStep ? Color.blue : Color.gray)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text("\(step)")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                            .bold()
                                    )
                                
                                if step < 4 {
                                    Rectangle()
                                        .fill(step < currentStep ? Color.blue : Color.gray)
                                        .frame(height: 2)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Step content
                        Group {
                            switch currentStep {
                            case 1:
                                personalInfoStep
                            case 2:
                                phoneValidationStep
                            case 3:
                                emailValidationStep
                            case 4:
                                completionStep
                            default:
                                personalInfoStep
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Sign Up")
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Step Views
    private var personalInfoStep: some View {
        VStack(spacing: 24) {
            Text("Personal Information")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.words)
                            if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("First name is required")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    if lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Last name is required")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Mobile Phone Number (10 digits)", text: $phoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: phoneNumber) { newValue in
                            phoneNumber = String(newValue.filter { $0.isNumber }.prefix(10))
                        }
                    if !phoneNumber.isEmpty && !isValidPhoneNumber {
                        Text("Please enter a valid 10-digit phone number")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button {
                Task {
                    await validatePhoneNumber()
                }
            } label: {
                Label("Send Verification Code", systemImage: "phone.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(canProceed ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!canProceed || isLoading)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            if !client.statusMessage.isEmpty {
                Text(client.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var phoneValidationStep: some View {
        VStack(spacing: 12) {
            Text("Phone Verification")
                .font(.title2)
                .bold()
            
            Text("We sent a verification code to \(phoneNumber)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("Enter verification code", text: $validationCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2)
                .onChange(of: validationCode) { newValue in
                    validationCode = String(newValue.filter { $0.isNumber }.prefix(10)) // Allow up to 10 digits
                }
            
            HStack(spacing: 16) {
                Button("Resend Code") {
                    Task {
                        await validatePhoneNumber()
                    }
                }
                .disabled(isLoading)
                
                Button("Verify Code") {
                    Task {
                        await validateCode()
                    }
                }
                .disabled(validationCode.isEmpty || isLoading)
                .buttonStyle(.borderedProminent)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            if !client.statusMessage.isEmpty {
                Text(client.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var emailValidationStep: some View {
        VStack(spacing: 24) {
            Text("Email Verification")
                .font(.title2)
                .bold()
            
            Text("This step will be implemented next")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Skip for Now") {
                currentStep = 4
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var completionStep: some View {
        VStack(spacing: 24) {
            Text("✅ Sign Up Complete!")
                .font(.title2)
                .bold()
                .foregroundColor(.green)
            
            Text("Ready for email verification")
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name: \(firstName) \(lastName)")
                Text("Phone: \(phoneNumber)")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Button("Start Over") {
                resetForm()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Computed Properties
    private var isValidPhoneNumber: Bool {
        phoneNumber.count == 10 && phoneNumber.allSatisfy { $0.isNumber }
    }
    
    private var isValidName: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var canProceed: Bool {
        isValidName && isValidPhoneNumber
    }
    
    // MARK: - Phone Number Validation
    private func validatePhoneNumber() async {
        guard canProceed else { 
            print("❌ Validation failed - Name valid: \(isValidName), Phone valid: \(isValidPhoneNumber)")
            return 
        }
        
        print("📱 Starting phone validation for: \(firstName) \(lastName) - \(phoneNumber)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await client.validatePhoneNumber(phoneNumber)
            print("✅ Phone validation successful: \(response)")
            phoneNumberGuid = response.phoneNumberGuid
            currentStep = 2 // Move to phone validation step
        } catch {
            print("❌ Phone validation failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            errorMessage = "Failed to send validation code: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    // MARK: - Code Validation
    private func validateCode() async {
        guard !validationCode.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await client.validatePhoneNumberCode(
                phoneNumberGuid: phoneNumberGuid,
                phoneNumber: phoneNumber,
                code: validationCode
            )
            
            if response.isValid {
                currentStep = 3 // Move to email validation step
                validationCode = ""
            } else {
                errorMessage = "Invalid code. Please try again."
                showingErrorAlert = true
            }
        } catch {
            errorMessage = "Failed to validate code: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    // MARK: - Helper Functions
    private func resetForm() {
        firstName = ""
        lastName = ""
        phoneNumber = ""
        validationCode = ""
        phoneNumberGuid = ""
        currentStep = 1
    }
}
