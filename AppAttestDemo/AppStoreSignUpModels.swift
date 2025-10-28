//
//  AppStoreSignUpModels.swift
//  AppAttestDemo
//
//  Models for App Store Sign Up phone number validation
//

import Foundation

// MARK: - Phone Number Validation Request
struct AppStoreSignUpValidatePhoneNumberRequest: Codable {
    let phoneNumber: String
    
    enum CodingKeys: String, CodingKey {
        case phoneNumber = "PhoneNumber"
    }
}

// MARK: - Phone Number Validation Response
struct AppStoreSignUpValidatePhoneNumberResponse: Codable {
    let phoneNumberGuid: String
    let phoneNumber: String
    
    enum CodingKeys: String, CodingKey {
        case phoneNumberGuid = "phoneNumberGuid"
        case phoneNumber = "phoneNumber"
    }
}

// MARK: - Phone Number Code Validation Request
struct AppStoreSignUpValidatePhoneNumberCodeRequest: Codable {
    let phoneNumberGuid: String
    let phoneNumber: String
    let code: String
    
    enum CodingKeys: String, CodingKey {
        case phoneNumberGuid = "PhoneNumberGuid"
        case phoneNumber = "PhoneNumber"
        case code = "Code"
    }
}

// MARK: - Phone Number Code Validation Response
struct AppStoreSignUpValidatePhoneNumberCodeResponse: Codable {
    let validPhoneNumberCodeGuid: String
    let phoneNumber: String
    let isValid: Bool
    
    enum CodingKeys: String, CodingKey {
        case validPhoneNumberCodeGuid = "validPhoneNumberCodeGuid"
        case phoneNumber = "phoneNumber"
        case isValid = "isValid"
    }
}
