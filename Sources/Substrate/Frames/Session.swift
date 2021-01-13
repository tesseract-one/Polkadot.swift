//
//  Session.swift
//  
//
//  Created by Yehor Popovych on 1/13/21.
//

import Foundation
import ScaleCodec

public protocol Session: System {
    associatedtype TValidatorId: ScaleDynamicCodable
    associatedtype TKeys: ScaleDynamicCodable
}

open class SessionModule<S: Session>: ModuleProtocol {
    public typealias Frame = S
    
    public static var NAME: String { "Session" }
    
    public init() {}
    
    open func registerEventsCallsAndTypes<R>(in registry: R) throws where R : TypeRegistryProtocol {
        try registry.register(type: S.TValidatorId.self, as: .type(name: "ValidatorId"))
        try registry.register(type: S.TKeys.self, as: .type(name: "Keys"))
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
    
    public init(decodingParamsFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        keys = try S.TKeys(from: decoder, registry: registry)
        proof = try decoder.decode()
    }
    
    public var params: [ScaleDynamicCodable] { [keys, proof] }
}

public struct SessionValidatorsStorageKey<S: Session> {}

extension SessionValidatorsStorageKey: StorageKey {
    public typealias Value = S.TValidatorId
    public typealias Module = SessionModule<S>
    
    public static var FIELD: String { "Validators" }
    
    public var path: [ScaleDynamicEncodable] { [] }
}
