//
//  Sudo.swift
//  
//
//  Created by Yehor Popovych on 1/13/21.
//

import Foundation
import ScaleCodec

public protocol Sudo: System {}

open class SudoModule<S: Sudo>: ModuleProtocol {
    public typealias Frame = S
    
    public static var NAME: String { "Sudo" }
    
    public init() {}
    
    open func registerEventsCallsAndTypes<R>(in registry: R) throws where R : TypeRegistryProtocol {
        try registry.register(call: SudoCall<S>.self)
        try registry.register(call: SudoUncheckedWeightCall<S>.self)
    }
}

/// Execute a transaction with sudo permissions.
public struct SudoCall<S: Sudo> {
    /// Encoded transaction.
    public let call: AnyCall
}

extension SudoCall: Call {
    public typealias Module = SudoModule<S>
    
    public static var FUNCTION: String { "sudo" }
    
    public var params: Dictionary<String, Any> { ["call": call] }
    
    public init(decodingParamsFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        call = try registry.decode(callFrom: decoder)
    }
    
    public func encode(paramsIn encoder: ScaleEncoder, registry: TypeRegistryProtocol) throws {
        try call.encode(in: encoder, registry: registry)
    }
}

/// Execute a transaction with sudo permissions without checking the call weight.
public struct SudoUncheckedWeightCall<S: Sudo> {
    /// Encoded transaction.
    public let call: AnyCall
    /// Call weight.
    ///
    /// This argument is actually unused in runtime, you can pass any value of
    /// `Weight` type when using this call.
    public let weight: S.TWeight
}

extension SudoUncheckedWeightCall: Call {
    public typealias Module = SudoModule<S>
    
    public static var FUNCTION: String { "sudo_unchecked_weight" }
    
    public var params: Dictionary<String, Any> { ["call": call, "weight": weight] }
    
    public init(decodingParamsFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        call = try registry.decode(callFrom: decoder)
        weight = try S.TWeight(from: decoder, registry: registry)
    }
    
    public func encode(paramsIn encoder: ScaleEncoder, registry: TypeRegistryProtocol) throws {
        try call.encode(in: encoder, registry: registry)
        try weight.encode(in: encoder, registry: registry)
    }
}
