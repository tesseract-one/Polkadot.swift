//
//  Signatures.swift
//  
//
//  Created by Yehor Popovych on 17/08/2023.
//

import Foundation
import ScaleCodec

public protocol SingleTypeStaticSignature: StaticSignature, FixedDataCodable, VoidValueRepresentable,
                                           IdentifiableType, Hashable, Equatable
{
    var raw: Data { get }
    static var algorithm: CryptoTypeId { get }
}

public extension SingleTypeStaticSignature {
    init(raw: Data, algorithm: CryptoTypeId, runtime: any Runtime) throws {
        guard algorithm == Self.algorithm else {
            throw CryptoError.unsupported(type: algorithm, supports: [Self.algorithm])
        }
        try self.init(decoding: raw)
    }
    
    @inlinable
    init(raw: Data) throws { try self.init(decoding: raw)}
    
    @inlinable
    var algorithm: CryptoTypeId { Self.algorithm }
    
    @inlinable
    func serialize() -> Data { raw }
    
    @inlinable
    static func algorithms(runtime: any Runtime) throws -> [CryptoTypeId] { [Self.algorithm] }
    
    @inlinable
    static var fixedBytesCount: Int { algorithm.signatureBytesCount }
    
    func asValue(of type: TypeDefinition,
                 in runtime: any Runtime) throws -> Value<TypeDefinition>
    {
        try validate(as: type, in: runtime).get()
        return .bytes(raw, type)
    }
    
    func asValue() -> Value<Void> { .bytes(raw) }
    
    static func definition(in registry: TypeRegistry<TypeDefinition.TypeId>) -> TypeDefinition.Builder {
        .array(count: UInt32(fixedBytesCount), of: registry.def(UInt8.self))
    }
    
    static func _validate(type: TypeDefinition) -> Result<Void, TypeError> {
        return AnySignature.parseTypeInfo(type: type).flatMap { types in
            guard types.count == 1, types.values.first == algorithm else {
                return .failure(.wrongType(for: Self.self, type: type,
                                           reason: "Unknown signature type: \(types)", .get()))
            }
            guard let count = type.asBytes() else {
                return .failure(.wrongType(for: Self.self, type: type,
                                           reason: "Signature is not byte sequence", .get()))
            }
            guard Self.fixedBytesCount == count else {
                return .failure(.wrongValuesCount(for: Self.self,
                                                  expected: Self.fixedBytesCount,
                                                  type: type, .get()))
            }
            return .success(())
        }
    }
}

public struct EcdsaSignature: SingleTypeStaticSignature {
    public let raw: Data
    
    public init(decoding data: Data) throws {
        guard data.count == Self.fixedBytesCount else {
            throw SizeMismatchError(size: data.count, expected: Self.fixedBytesCount)
        }
        raw = data
    }
    
    @inlinable
    public static func validate(as type: TypeDefinition,
                                in runtime: any Runtime) -> Result<Void, TypeError>
    {
        _validate(type: type)
    }
    
    @inlinable
    public static var algorithm: CryptoTypeId { .ecdsa }
}

public struct Ed25519Signature: SingleTypeStaticSignature {
    public let raw: Data

    public init(decoding data: Data) throws {
        guard data.count == Self.fixedBytesCount else {
            throw SizeMismatchError(size: data.count, expected: Self.fixedBytesCount)
        }
        raw = data
    }
    
    @inlinable
    public static func validate(as type: TypeDefinition,
                                in runtime: any Runtime) -> Result<Void, TypeError>
    {
        _validate(type: type)
    }
    
    @inlinable
    public static var algorithm: CryptoTypeId { .ed25519 }
}

public struct Sr25519Signature: SingleTypeStaticSignature {
    public let raw: Data
    
    public init(decoding data: Data) throws {
        guard data.count == Self.fixedBytesCount else {
            throw SizeMismatchError(size: data.count, expected: Self.fixedBytesCount)
        }
        raw = data
    }
    
    @inlinable
    public static func validate(as type: TypeDefinition,
                                in runtime: any Runtime) -> Result<Void, TypeError>
    {
        _validate(type: type)
    }
    
    @inlinable
    public static var algorithm: CryptoTypeId { .sr25519 }
}
