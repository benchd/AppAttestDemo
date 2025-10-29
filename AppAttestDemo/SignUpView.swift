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
    @State private var currentStep = 1 // 1: Personal Info, 2: Phone Validation, 3: Email Validation, 4: Company Details, 5: Complete
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var codeValidationError = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: 5)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Step indicator
                        HStack {
                            ForEach(1...5, id: \.self) { step in
                                Circle()
                                    .fill(step <= currentStep ? Color.blue : Color.gray)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text("\(step)")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                            .bold()
                                    )
                                
                                if step < 5 {
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
                                companyDetailsStep
                            case 5:
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
        EmailStepView(
            client: client,
            validPhoneNumberCodeGuid: client.lastValidPhoneNumberCodeGuid ?? "",
            onComplete: { _ in
                currentStep = 4
            }
        )
    }
    
    private var companyDetailsStep: some View {
        CompanyDetailsStepView(
            client: client,
            firstName: firstName,
            lastName: lastName,
            onComplete: {
                currentStep = 5
            }
        )
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

// MARK: - Email Step View
private struct EmailStepView: View {
    @ObservedObject var client: AppAttestClient
    let validPhoneNumberCodeGuid: String
    var onComplete: (AppStoreSignUpValidateEmailResponse) -> Void

    @State private var email: String = ""
    @State private var emailCode: String = ""
    @State private var isLoading: Bool = false
    @State private var message: String = ""
    @State private var hasSentCode: Bool = false
    @State private var showChangeEmailSheet: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Email Verification")
                .font(.title2)
                .bold()

            if !hasSentCode {
                // Step A: Enter email and send code
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Email Address", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !email.isEmpty && !isValidEmail(email) {
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Button("Send Code") {
                    Task { await sendOrResendCode() }
                }
                .disabled(!isValidEmail(email) || isLoading)
                .buttonStyle(.borderedProminent)
            } else {
                // Step B: Enter code, then verify, then change/resend options
                VStack(spacing: 8) {
                    Text("Code sent to \(email)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Enter verification code", text: $emailCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .onChange(of: emailCode) { newValue in
                            emailCode = String(newValue.filter { $0.isNumber }.prefix(10))
                        }

                    Button("Verify Email") { Task { await verifyCode() } }
                        .disabled(emailCode.isEmpty || isLoading)
                        .buttonStyle(.borderedProminent)

                    HStack(spacing: 12) {
                        Button("Change Email") { showChangeEmailSheet = true }
                        Button("Resend Code") { Task { await sendOrResendCode() } }
                            .disabled(isLoading)
                        Spacer()
                    }
                }
            }

            if isLoading { ProgressView() }

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .sheet(isPresented: $showChangeEmailSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    TextField("Email Address", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                    Spacer()
                }
                .navigationTitle("Change Email")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showChangeEmailSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { showChangeEmailSheet = false }
                            .disabled(!isValidEmail(email))
                    }
                }
            }
        }
    }

    private func sendOrResendCode() async {
        guard isValidEmail(email) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await client.issueOrValidateEmail(
                validPhoneNumberCodeGuid: validPhoneNumberCodeGuid,
                email: email,
                validationCode: ""
            )
            hasSentCode = true
            message = resp.isValidEmail ? "Email already validated" : "We sent a code to \(email)."
            if resp.isValidEmail { onComplete(resp) }
        } catch {
            message = "Failed to send email code: \(error.localizedDescription)"
        }
    }

    private func verifyCode() async {
        guard !emailCode.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await client.issueOrValidateEmail(
                validPhoneNumberCodeGuid: validPhoneNumberCodeGuid,
                email: email,
                validationCode: emailCode
            )
            if resp.isValidEmail {
                onComplete(resp)
            } else {
                message = "Invalid code. Please try again."
            }
        } catch {
            message = "Failed to validate email: \(error.localizedDescription)"
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Simple RFC 5322-ish check
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// MARK: - Company Details Step View
private struct CompanyDetailsStepView: View {
    @ObservedObject var client: AppAttestClient
    let firstName: String
    let lastName: String
    var onComplete: () -> Void
    
    @State private var companyName: String = ""
    @State private var addressLine1: String = ""
    @State private var addressLine2: String = ""
    @State private var city: String = ""
    @State private var selectedState: String = ""
    @State private var zipCode: String = ""
    @State private var isLoading: Bool = false
    @State private var message: String = ""
    
    private let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Company Information")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 12) {
                TextField("Company Name", text: $companyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                
                TextField("Address Line 1", text: $addressLine1)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                
                TextField("Address Line 2 (Optional)", text: $addressLine2)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                
                TextField("City", text: $city)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                
                Picker("State", selection: $selectedState) {
                    Text("Select State").tag("")
                    ForEach(states, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                TextField("Zip Code", text: $zipCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .onChange(of: zipCode) { newValue in
                        zipCode = String(newValue.filter { $0.isNumber }.prefix(5))
                    }
            }
            
            Button("Complete Sign Up") {
                Task { await createSignUp() }
            }
            .disabled(!canProceed || isLoading)
            .buttonStyle(.borderedProminent)
            
            if isLoading {
                ProgressView()
            }
            
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var canProceed: Bool {
        !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedState.isEmpty &&
        zipCode.count == 5
    }
    
    private func createSignUp() async {
        guard canProceed else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await client.createSignUpDetails(
                firstName: firstName,
                lastName: lastName,
                companyName: companyName,
                addressLine1: addressLine1,
                addressLine2: addressLine2,
                city: city,
                state: selectedState,
                zipCode: zipCode
            )
            message = "Sign up completed successfully!"
            onComplete()
        } catch {
            message = "Failed to complete sign up: \(error.localizedDescription)"
        }
    }
}