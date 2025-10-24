//
//  AttestResponse.swift
//  AppAttestDemo
//
//  Created by David Bench on 10/24/25.
//

struct AttestResponse: Codable {
    let status: String
    let verified: Bool
    let message: String
}

