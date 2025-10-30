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

// MARK: - Email Validation
// Request to issue/verify email validation code. When ValidationCode is empty, server sends an email.
struct AppStoreSignUpValidateEmailRequest: Codable {
    let validPhoneNumberCodeGuid: String
    let email: String
    let validationCode: String
    
    enum CodingKeys: String, CodingKey {
        case validPhoneNumberCodeGuid = "ValidPhoneNumberCodeGuid"
        case email = "Email"
        case validationCode = "ValidationCode"
    }
}

struct AppStoreSignUpValidateEmailResponse: Codable {
    let isValidEmail: Bool
    let validPhoneNumberCodeGuid: String
    let emailGuid: String
    
    enum CodingKeys: String, CodingKey {
        case isValidEmail = "isValidEmail"
        case validPhoneNumberCodeGuid = "validPhoneNumberCodeGuid"
        case emailGuid = "emailGuid"
    }
}

// MARK: - Sign Up Create Details
struct AppStoreSignUpCreateDetails: Codable {
    let firstName: String
    let lastName: String
    let companyName: String
    let addressLine1: String
    let addressLine2: String
    let city: String
    let state: String
    let zipCode: String
    let validPhoneNumberCodeGuid: String
    let validEmailCodeGuid: String
    
    enum CodingKeys: String, CodingKey {
        case firstName = "FirstName"
        case lastName = "LastName"
        case companyName = "CompanyName"
        case addressLine1 = "AddressLine1"
        case addressLine2 = "AddressLine2"
        case city = "City"
        case state = "State"
        case zipCode = "ZipCode"
        case validPhoneNumberCodeGuid = "ValidPhoneNumberCodeGuid"
        case validEmailCodeGuid = "ValidEmailCodeGuid"
    }
}

// MARK: - Sign Up Create Details Response
struct AppStoreSignUpCreateDetailsResponse: Codable {
    let deviceCode: String

    enum CodingKeys: String, CodingKey {
        case deviceCode = "deviceCode"
    }
}
