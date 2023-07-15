//
//  CryptoTypeId.swift
//  
//
//  Created by Yehor Popovych on 04.05.2021.
//

import Foundation

public enum CryptoTypeId: String, Hashable, Equatable, CustomStringConvertible {
    case ed25519 = "ed25"
    case sr25519 = "sr25"
    case ecdsa = "ecds"
    
    public var description: String { signatureName }
    
    public var signatureName: String {
        switch self {
        case .ecdsa: return "Ecdsa"
        case .ed25519: return "Ed25519"
        case .sr25519: return "Sr25519"
        }
    }
    
    public static let byName: [String: CryptoTypeId] = [
        CryptoTypeId.ecdsa.signatureName.lowercased(): .ecdsa,
        CryptoTypeId.ed25519.signatureName.lowercased(): .ed25519,
        CryptoTypeId.sr25519.signatureName.lowercased(): .sr25519
    ]
}

public enum CryptoError: Error {
    case unsupported(type: CryptoTypeId, supports: [CryptoTypeId])
}
