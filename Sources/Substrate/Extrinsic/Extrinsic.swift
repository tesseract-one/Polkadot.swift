//
//  Extrinsic.swift
//  
//
//  Created by Yehor Popovych on 12.01.2023.
//

import Foundation
import ScaleCodec

public struct Extrinsic<C: Call, Extra: ExtrinsicExtra>: CustomStringConvertible, CallHolder {
    public typealias TCall = C
    
    public let call: C
    public let extra: Extra
    
    @inlinable
    public var isSigned: Bool { extra.isSigned }
    
    @inlinable
    public init(call: C, extra: Extra) {
        self.call = call
        self.extra = extra
    }
    
    public var description: String {
        "\(isSigned ? "SignedExtrinsic" : "UnsignedExtrinsic")(call: \(call), extra: \(extra))"
    }
}

public protocol ExtrinsicExtra {
    var isSigned: Bool { get }
}

public struct ExtrinsicSignPayload<C: Call, Extra>: CustomStringConvertible, CallHolder {
    public typealias TCall = C
    
    public let call: C
    public let extra: Extra
    
    @inlinable
    public init(call: C, extra: Extra) {
        self.call = call
        self.extra = extra
    }
    
    public var description: String {
        "ExtrinsicPayload(call: \(call), extra: \(extra))"
    }
}

extension Nothing: ExtrinsicExtra {
    public var isSigned: Bool { false }
}

extension Either: ExtrinsicExtra where Left: ExtrinsicExtra, Right: ExtrinsicExtra {
    public var isSigned: Bool {
        switch self {
        case .left(let l): return l.isSigned
        case .right(let r): return r.isSigned
        }
    }
}

public protocol OpaqueExtrinsic<THash, TSignedExtra, TUnsignedExtra>: RuntimeSwiftDecodable, ValidatableType {
    associatedtype THash: Hash
    associatedtype TSignedExtra: ExtrinsicExtra
    associatedtype TUnsignedExtra: ExtrinsicExtra
    
    func hash() -> THash
    
    func decode<C: Call & RuntimeDecodable>() throws -> Extrinsic<C, Either<TUnsignedExtra, TSignedExtra>>
    
    static var version: UInt8 { get }
}


public protocol SomeExtrinsicEra: RuntimeLazyDynamicCodable, ValueRepresentable, ValidatableType, Default {
    var isImmortal: Bool { get }
    
    func blockHash<R: RootApi>(api: R) async throws -> R.RC.TBlock.THeader.THasher.THash
    
    static var immortal: Self { get }
}

public extension SomeExtrinsicEra {
    static var `default`: Self { Self.immortal }
}

public enum ExtrinsicCodingError: Error {
    case badExtrinsicVersion(supported: UInt8, got: UInt8)
    case badExtrasCount(expected: Int, got: Int)
    case parameterNotFound(extension: ExtrinsicExtensionId, parameter: String)
    case typeMismatch(expected: Any.Type, got: Any.Type)
    case unknownExtension(identifier: ExtrinsicExtensionId)
}

public protocol SomeExtrinsicFailureEvent: PalletEvent {
    associatedtype Err: Error
    var error: Err { get }
}

public protocol SomeDispatchError: CallError {
    var isModuleError: Bool { get }
    var moduleErrorInfo: (name: String, pallet: String) { get throws }
    
    func typedModuleError<E: PalletError>(_ type: E.Type) throws -> E
    var anyModuleError: AnyModuleError { get throws }
}

public extension SomeDispatchError {
    var anyModuleError: AnyModuleError { get throws {
        try typedModuleError(AnyModuleError.self)
    }}
}
