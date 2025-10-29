//
//  AppAttestClient.swift
//  AppAttestDemo
//
//  Updated for UnifiedAttestController endpoints
//

// https://ss.myprohelper.com:5012/ga/status - ga status page on pico
import Foundation
import DeviceCheck
import Combine
import CryptoKit

@MainActor
final class AppAttestClient: ObservableObject {
    // MARK: - Constants
    private static let baseServerURL = "https://ss.myprohelper.com:5012"
//    private static let baseServerURL = "https://myprohelper.com:5005"
    private static let unifiedAttestEndpoint = "\(baseServerURL)/ga/sixshooter"
    private static let secureDataEndpoint = "\(baseServerURL)/ga/securedata/info"
    
    static let shared = AppAttestClient()

    @Published var statusMessage: String = ""
    @Published var jwtToken: String? = nil
    @Published var isAttested: Bool = false
    @Published var lastValidPhoneNumberCodeGuid: String? = nil
    @Published var lastValidEmailCodeGuid: String? = nil

    private let service = DCAppAttestService.shared
    private let serverBaseURL = URL(string: unifiedAttestEndpoint)!
    private var keyId: String?

    private init() {}
    
    // MARK: - Helper Functions
    private func currentTimestamp() -> String {
        return DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    }
    
    // MARK: - Phone Number Validation
    func validatePhoneNumber(_ phoneNumber: String) async throws -> AppStoreSignUpValidatePhoneNumberResponse {
        // If no JWT token, get one first
        if jwtToken == nil {
            statusMessage = "No JWT token - getting new one... (\(currentTimestamp()))"
            await runFullAttestationFlow()
            
            guard jwtToken != nil else {
                throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "Failed to get JWT token for phone validation"])
            }
        }
        
        guard let jwt = jwtToken else {
            throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "No JWT token available"])
        }
        
        let url = URL(string: "\(Self.baseServerURL)/ga/SecureData/IssueValidatePhoneNumber")!
        let request = AppStoreSignUpValidatePhoneNumberRequest(phoneNumber: phoneNumber)
        
        print("📱 Phone validation request URL: \(url)")
        print("📱 Phone validation request data: \(request)")
        print("📱 JWT token: \(jwt.prefix(20))...")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            print("📱 Request body encoded successfully")
        } catch {
            print("❌ Failed to encode request: \(error)")
            throw NSError(domain: "AppAttest", code: -101, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request: \(error.localizedDescription)"])
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Phone validation error: Bad server response")
            throw URLError(.badServerResponse)
        }
        
        print("📱 Phone validation response: Status \(httpResponse.statusCode)")
        print("📱 Phone validation response headers: \(httpResponse.allHeaderFields)")
        
        if httpResponse.statusCode == 200 {
            do {
                let response = try JSONDecoder().decode(AppStoreSignUpValidatePhoneNumberResponse.self, from: data)
                print("✅ Phone validation success: \(response)")
                return response
            } catch {
                print("❌ Phone validation decode error: \(error)")
                print("❌ Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
                throw NSError(domain: "AppAttest", code: -102, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])
            }
        } else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Phone validation server error: \(httpResponse.statusCode)")
            print("❌ Phone validation error response: \(errorText)")
            throw NSError(domain: "AppAttest", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
    }
    
    func validatePhoneNumberCode(phoneNumberGuid: String, phoneNumber: String, code: String) async throws -> AppStoreSignUpValidatePhoneNumberCodeResponse {
        // If no JWT token, get one first
        if jwtToken == nil {
            statusMessage = "No JWT token - getting new one... (\(currentTimestamp()))"
            await runFullAttestationFlow()
            
            guard jwtToken != nil else {
                throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "Failed to get JWT token for code validation"])
            }
        }
        
        guard let jwt = jwtToken else {
            throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "No JWT token available"])
        }
        
        let url = URL(string: "\(Self.baseServerURL)/ga/SecureData/IssueValidatePhoneNumberCode")!
        let request = AppStoreSignUpValidatePhoneNumberCodeRequest(
            phoneNumberGuid: phoneNumberGuid,
            phoneNumber: phoneNumber,
            code: code
        )
        
        print("📱 Code validation request URL: \(url)")
        print("📱 Code validation request data: \(request)")
        print("📱 JWT token: \(jwt.prefix(20))...")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            print("📱 Code validation request body encoded successfully")
        } catch {
            print("❌ Failed to encode code validation request: \(error)")
            throw NSError(domain: "AppAttest", code: -101, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request: \(error.localizedDescription)"])
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Code validation error: Bad server response")
            throw URLError(.badServerResponse)
        }
        
        print("📱 Code validation response: Status \(httpResponse.statusCode)")
        print("📱 Code validation response headers: \(httpResponse.allHeaderFields)")
        
        if httpResponse.statusCode == 200 {
            do {
                let response = try JSONDecoder().decode(AppStoreSignUpValidatePhoneNumberCodeResponse.self, from: data)
                print("✅ Code validation success: \(response)")
                // Save for downstream email validation step
                self.lastValidPhoneNumberCodeGuid = response.validPhoneNumberCodeGuid
                return response
            } catch {
                print("❌ Code validation decode error: \(error)")
                print("❌ Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
                throw NSError(domain: "AppAttest", code: -102, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])
            }
        } else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Code validation server error: \(httpResponse.statusCode)")
            print("❌ Code validation error response: \(errorText)")
            
            // Try to parse the error response for better user feedback
            if let errorData = errorText.data(using: .utf8),
               let errorJson = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let status = errorJson["status"] as? String {
                throw NSError(domain: "AppAttest", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: status])
            } else {
                throw NSError(domain: "AppAttest", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
            }
        }
    }

    // MARK: - Email Validation
    func issueOrValidateEmail(
        validPhoneNumberCodeGuid: String,
        email: String,
        validationCode: String
    ) async throws -> AppStoreSignUpValidateEmailResponse {
        // Ensure JWT
        if jwtToken == nil {
            statusMessage = "No JWT token - getting new one... (\(currentTimestamp()))"
            await runFullAttestationFlow()
            guard jwtToken != nil else {
                throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "Failed to get JWT token for email validation"])
            }
        }
        guard let jwt = jwtToken else {
            throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "No JWT token available"])
        }

        let url = URL(string: "\(Self.baseServerURL)/ga/SecureData/IssueValidateEmail")!
        let requestBody = AppStoreSignUpValidateEmailRequest(
            validPhoneNumberCodeGuid: validPhoneNumberCodeGuid,
            email: email,
            validationCode: validationCode
        )

        print("📧 Email validation request URL: \(url)")
        print("📧 Email request data: \(requestBody)")
        print("📧 JWT token: \(jwt.prefix(20))...")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        print("📧 Email validation response: Status \(httpResponse.statusCode)")
        if httpResponse.statusCode == 200 {
            do {
                let decoded = try JSONDecoder().decode(AppStoreSignUpValidateEmailResponse.self, from: data)
                print("✅ Email step response: \(decoded)")
                // Save email code GUID for final signup
                if decoded.isValidEmail {
                    self.lastValidEmailCodeGuid = decoded.emailGuid
                }
                return decoded
            } catch {
                print("❌ Email step decode error: \(error)")
                print("❌ Raw: \(String(data: data, encoding: .utf8) ?? "<nil>")")
                throw NSError(domain: "AppAttest", code: -102, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])
            }
        } else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Email step server error: \(httpResponse.statusCode)")
            print("❌ Email step error response: \(text)")
            throw NSError(domain: "AppAttest", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
        }
    }
    
    // MARK: - Create Sign Up Details
    func createSignUpDetails(
        firstName: String,
        lastName: String,
        companyName: String,
        addressLine1: String,
        addressLine2: String,
        city: String,
        state: String,
        zipCode: String
    ) async throws {
        // Ensure JWT
        if jwtToken == nil {
            statusMessage = "No JWT token - getting new one... (\(currentTimestamp()))"
            await runFullAttestationFlow()
            guard jwtToken != nil else {
                throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "Failed to get JWT token for signup creation"])
            }
        }
        guard let jwt = jwtToken else {
            throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "No JWT token available"])
        }
        
        guard let phoneGuid = lastValidPhoneNumberCodeGuid,
              let emailGuid = lastValidEmailCodeGuid else {
            throw NSError(domain: "AppAttest", code: -103, userInfo: [NSLocalizedDescriptionKey: "Missing phone or email validation GUIDs"])
        }
        
        let url = URL(string: "\(Self.baseServerURL)/ga/SecureData/SignUpCreate")!
        let requestBody = AppStoreSignUpCreateDetails(
            firstName: firstName,
            lastName: lastName,
            companyName: companyName,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            state: state,
            zipCode: zipCode,
            validPhoneNumberCodeGuid: phoneGuid,
            validEmailCodeGuid: emailGuid
        )
        
        print("📝 SignUp create request URL: \(url)")
        print("📝 SignUp create request data: \(requestBody)")
        print("📝 JWT token: \(jwt.prefix(20))...")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📝 SignUp create response: Status \(httpResponse.statusCode)")
        if httpResponse.statusCode == 200 {
            print("✅ SignUp create successful")
        } else if httpResponse.statusCode == 401 {
            // JWT expired - get a new one and retry
            statusMessage = "JWT expired - getting new token and retrying signup... (\(currentTimestamp()))"
            jwtToken = nil // Clear expired token
            await runFullAttestationFlow()
            
            if jwtToken != nil {
                statusMessage = "Retrying signup with new JWT... (\(currentTimestamp()))"
                // Recursive retry with new JWT
                try await createSignUpDetails(
                    firstName: firstName,
                    lastName: lastName,
                    companyName: companyName,
                    addressLine1: addressLine1,
                    addressLine2: addressLine2,
                    city: city,
                    state: state,
                    zipCode: zipCode
                )
            } else {
                throw NSError(domain: "AppAttest", code: -100, userInfo: [NSLocalizedDescriptionKey: "Failed to get new JWT token for signup retry"])
            }
        } else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ SignUp create server error: \(httpResponse.statusCode)")
            print("❌ SignUp create error response: \(text)")
            throw NSError(domain: "AppAttest", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
        }
    }

    // MARK: - Initialization
    func initializeIfNeeded() async {
        #if targetEnvironment(simulator)
        // Allow testing on simulator - bypass isSupported check
        statusMessage = "Simulator detected - App Attest will be simulated (\(currentTimestamp()))"
        #else
        guard service.isSupported else {
            statusMessage = "App Attest not supported on this device. (\(currentTimestamp()))"
            return
        }
        #endif

        statusMessage = "Initializing App Attest... (\(currentTimestamp()))"
        do {
            let storedKeyId = UserDefaults.standard.string(forKey: "AppAttestKeyId")
            if let keyId = storedKeyId {
                self.keyId = keyId
                statusMessage = "Existing App Attest key found ✅ (\(currentTimestamp()))"
            } else {
                #if targetEnvironment(simulator)
                // Generate a fake key for simulator testing
                let newKeyId = "simulator-key-\(UUID().uuidString)"
                self.keyId = newKeyId
                UserDefaults.standard.set(newKeyId, forKey: "AppAttestKeyId")
                statusMessage = "Generated simulator test key ✅ (\(currentTimestamp()))"
                #else
                let newKeyId = try await service.generateKey()
                self.keyId = newKeyId
                UserDefaults.standard.set(newKeyId, forKey: "AppAttestKeyId")
                statusMessage = "Generated new App Attest key ✅ (\(currentTimestamp()))"
                #endif
            }
        } catch {
            statusMessage = "Failed to initialize App Attest: \(error.localizedDescription) (\(currentTimestamp()))"
        }
    }

    // MARK: - Full attestation flow
    func runFullAttestationFlow() async {
        statusMessage = "Fetching challenge... (\(currentTimestamp()))"
        do {
            let challenge = try await fetchChallenge()

            #if targetEnvironment(simulator)
            // Use existing key for simulator testing
            guard let keyId = self.keyId else {
                throw NSError(domain: "AppAttest", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "No simulator key available"])
            }
            #else
            guard service.isSupported else {
                throw NSError(domain: "AppAttest", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "App Attest not supported on this device"])
            }

            // Generate or reuse key
            let keyId = try await service.generateKey()
            self.keyId = keyId
            #endif

            // Correct Base64 decode before SHA256
            guard let challengeData = Data(base64Encoded: challenge) else {
                throw NSError(domain: "AppAttest", code: -10,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid Base64 challenge"])
            }

            let clientDataHash = Data(SHA256.hash(data: challengeData))
            print("ClientDataHash (Base64): \(clientDataHash.base64EncodedString())")

            statusMessage = "Generating attestation... (\(currentTimestamp()))"
            let attestation: Data
            #if targetEnvironment(simulator)
            // Create fake attestation data for simulator testing
            let fakeAttestation = "simulator-attestation-\(UUID().uuidString)"
            attestation = fakeAttestation.data(using: .utf8) ?? Data()
            #else
            attestation = try await withTimeout(seconds: 20) { [self] in
                try await service.attestKey(keyId, clientDataHash: clientDataHash)
            }
            #endif

            statusMessage = "Sending attestation to server... (\(currentTimestamp()))"
            let jwt = try await sendAttestation(
                keyId: keyId,
                attestationObject: attestation,
                challenge: challenge
            )

            self.jwtToken = jwt
            statusMessage = "✅ Attestation successful (\(currentTimestamp()))"
        } catch {
            statusMessage = "❌ Attestation failed: \(error.localizedDescription) (\(error)) (\(currentTimestamp()))"
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

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
        // ✅ FIXED ENDPOINT for UnifiedAttestController
        let url = serverBaseURL.appendingPathComponent("verify")
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
            statusMessage = "❌ No JWT available. Please attest first. (\(currentTimestamp()))"
            return
        }

        let url = URL(string: Self.secureDataEndpoint)!

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
                let timestamp = currentTimestamp()
                print("✅ Secure response (\(timestamp)): \(json ?? [:])")
                statusMessage = "✅ Secure response (\(timestamp)): \(json ?? [:])"
            } else {
                let text = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Secure endpoint error: \(text)")
                statusMessage = "❌ Secure endpoint failed (\(httpResponse.statusCode)) (\(currentTimestamp()))"
            }
        } catch {
            statusMessage = "❌ Network error: \(error.localizedDescription) (\(currentTimestamp()))"
        }
    }
    
    // MARK: - Smart Secure Request (auto-handles JWT and 401 retry)
    func smartSecureRequest() async {
        // If no JWT, get one first
        if jwtToken == nil {
            statusMessage = "No JWT token - getting new one... (\(currentTimestamp()))"
            await runFullAttestationFlow()
            
            // If attestation failed, stop here
            if jwtToken == nil {
                statusMessage = "❌ Failed to get JWT token (\(currentTimestamp()))"
                return
            }
        }
        
        // Try the secure request
        await callSecureEndpointWithRetry()
    }
    
    // MARK: - Secure endpoint with 401 retry logic
    private func callSecureEndpointWithRetry() async {
        let url = URL(string: Self.secureDataEndpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwtToken!)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let timestamp = currentTimestamp()
                print("✅ Secure response (\(timestamp)): \(json ?? [:])")
                statusMessage = "✅ Secure response (\(timestamp)): \(json ?? [:])"
            } else if httpResponse.statusCode == 401 {
                // JWT expired - get a new one and retry
                statusMessage = "JWT expired - getting new token and retrying... (\(currentTimestamp()))"
                jwtToken = nil // Clear expired token
                await runFullAttestationFlow()
                
                if jwtToken != nil {
                    statusMessage = "Retrying with new JWT... (\(currentTimestamp()))"
                    await callSecureEndpointWithRetry() // Recursive retry
                } else {
                    statusMessage = "❌ Failed to get new JWT token (\(currentTimestamp()))"
                }
            } else {
                let text = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Secure endpoint error: \(text)")
                statusMessage = "❌ Secure endpoint failed (\(httpResponse.statusCode)) (\(currentTimestamp()))"
            }
        } catch {
            statusMessage = "❌ Network error: \(error.localizedDescription) (\(currentTimestamp()))"
        }
    }
}
