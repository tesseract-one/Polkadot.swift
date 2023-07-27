//
//  Hashes.swift
//  
//
//  Created by Yehor Popovych on 10/8/20.
//

import Foundation
import ScaleCodec
import ContextCodable

public protocol Hash: ContextDecodable, Swift.Encodable,
                      ValueRepresentable, VoidValueRepresentable,
                      Equatable, CustomStringConvertible
    where DecodingContext == (metadata: any Metadata, id: () throws -> RuntimeType.Id)
{
    var raw: Data { get }
    
    init(raw: Data,
         metadata: any Metadata,
         id: @escaping () throws -> RuntimeType.Id) throws
}

public extension Hash {
    var description: String { raw.hex() }
    
    @inlinable
    init(raw: Data,
         runtime: any Runtime,
         id: @escaping RuntimeType.LazyId) throws
    {
        try self.init(raw: raw, metadata: runtime.metadata) { try id(runtime) }
    }
    
    func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
    
    func asValue(runtime: Runtime, type: RuntimeType.Id) throws -> Value<RuntimeType.Id> {
        guard let info = runtime.resolve(type: type) else {
            throw ValueRepresentableError.typeNotFound(type)
        }
        guard let count = info.asBytes(metadata: runtime.metadata) else {
            throw ValueRepresentableError.wrongType(got: info, for: String(describing: Self.self))
        }
        guard count == 0 || raw.count == count else {
            throw ValueRepresentableError.wrongValuesCount(in: info, expected: raw.count,
                                                           for: String(describing: Self.self))
        }
        return .bytes(raw, type)
    }
     
    func asValue() -> Value<Void> {
         .bytes(raw)
     }
}

public protocol StaticHash: Hash, FixedDataCodable, RuntimeCodable, Swift.Decodable {
    init(raw: Data) throws
}

public extension StaticHash {
    @inlinable
    init(raw: Data,
         metadata: any Metadata,
         id: @escaping () throws -> RuntimeType.Id) throws
    {
        try self.init(raw: raw)
    }
    
    init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        try self.init(raw: data)
    }
    
    @inlinable
    init(decoding data: Data) throws {
       try self.init(raw: data)
    }
    
    @inlinable
    init(from decoder: Swift.Decoder, context: DecodingContext) throws {
        try self.init(from: decoder)
    }
    
    @inlinable
    func serialize() -> Data { raw }
}

public struct Hash128: StaticHash {
    public let raw: Data
    
    public init(raw: Data) throws {
        guard raw.count == Self.fixedBytesCount else {
            throw SizeMismatchError(size: raw.count, expected: Self.fixedBytesCount)
        }
        self.raw = raw
    }
    
    public static var fixedBytesCount: Int = 16
}

public struct Hash160: StaticHash {
    public let raw: Data
    
    public init(raw: Data) throws {
        guard raw.count == Self.fixedBytesCount else {
            throw SizeMismatchError(size: raw.count, expected: Self.fixedBytesCount)
        }
        self.raw = raw
    }
    
    public static var fixedBytesCount: Int = 20
}

public struct Hash256: StaticHash {
    public let raw: Data
    
    public init(raw: Data) throws {
        guard raw.count == Self.fixedBytesCount else {
            throw SizeMismatchError(size: raw.count, expected: Self.fixedBytesCount)
        }
        self.raw = raw
    }
    
    public static var fixedBytesCount: Int = 32
}

public struct Hash512: StaticHash {
    public let raw: Data
    
    public init(raw: Data) throws {
        guard raw.count == Self.fixedBytesCount else {
            throw SizeMismatchError(size: raw.count, expected: Self.fixedBytesCount)
        }
        self.raw = raw
    }
    
    public static var fixedBytesCount: Int = 64
}

public struct AnyHash: Hash {
    public let raw: Data
    
    public init(unchecked raw: Data) {
        self.raw = raw
    }
    
    public init(raw: Data,
                metadata: any Metadata,
                id: @escaping () throws -> RuntimeType.Id) throws
    {
        let type = try id()
        guard let info = metadata.resolve(type: type) else {
            throw ValueRepresentableError.typeNotFound(type)
        }
        guard let count = info.asBytes(metadata: metadata) else {
            throw ValueRepresentableError.wrongType(got: info, for: "AnyHash")
        }
        guard count == 0 || count == raw.count else {
            throw SizeMismatchError(size: raw.count, expected: Int(count))
        }
        self.raw = raw
    }
    
    public init(from decoder: Swift.Decoder, context: DecodingContext) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        try self.init(raw: data, metadata: context.metadata, id: context.id)
    }
}

public struct SizeMismatchError: Error {
    public let size: Int
    public let expected: Int
    
    public init(size: Int, expected: Int) {
        self.size = size; self.expected = expected
    }
}
