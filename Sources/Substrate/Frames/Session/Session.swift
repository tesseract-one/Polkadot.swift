//
//  Session.swift
//  
//
//  Created by Yehor Popovych on 1/13/21.
//

import Foundation
import ScaleCodec

public protocol Session: System {
    associatedtype TValidatorId: PublicKey & Hashable //& SDefault
    associatedtype TKeys: SessionKeys
}

open class SessionModule<S: Session>: ModuleProtocol {
    public typealias Frame = S
    
    public static var NAME: String { "Session" }
    
    public init() {}
    
    open func registerEventsCallsAndTypes<R>(in registry: R) throws where R : TypeRegistryProtocol {
        try registry.register(type: S.TValidatorId.self, as: .type(name: "ValidatorId"))
        try registry.register(type: S.TKeys.self, as: .type(name: "SessionKeys"))
        try registry.register(call: SessionSetKeysCall<S>.self)
    }
}

public struct SessionSetKeysCall<S: Session> {
    /// The keys
    public let keys: S.TKeys
    /// The proof. This is not currently used and can be set to an empty data.
    public let proof: Data
}

extension SessionSetKeysCall: Call {
    public typealias Module = SessionModule<S>
    
    public static var FUNCTION: String { "set_keys" }
    
    public var params: Dictionary<String, Any> { ["keys": keys, "proof": proof] }
    
    public init(decodingParamsFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        keys = try S.TKeys(from: decoder, registry: registry)
        proof = try decoder.decode()
    }
    
    public func encode(paramsIn encoder: ScaleEncoder, registry: TypeRegistryProtocol) throws {
        try keys.encode(in: encoder, registry: registry)
        try proof.encode(in: encoder, registry: registry)
    }
}

public struct SessionValidatorsStorageKey<S: Session> {
    public init() {}
}

extension SessionValidatorsStorageKey: PlainStorageKey {
    public typealias Value = S.TValidatorId
    public typealias Module = SessionModule<S>
    
    public static var FIELD: String { "Validators" }
}
