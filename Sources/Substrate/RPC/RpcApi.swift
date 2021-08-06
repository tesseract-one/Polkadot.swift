//
//  RpcApi.swift
//  
//
//  Created by Yehor Popovych on 1/11/21.
//

import Foundation
import SubstrateRpc
import ScaleCodec

public protocol SubstrateRpcApi {
    associatedtype S: SubstrateProtocol
    
    static var id: String { get }
    
    var substrate: S! { get }
    
    init(substrate: S)
}

extension SubstrateRpcApi {
    public static var id: String { String(describing: self) }
    
    func _encode<V: ScaleDynamicEncodable>(_ value: V) -> SRpcApiResult<Data> {
        return Result {
            let encoder = SCALE.default.encoder()
            try value.encode(in: encoder, registry: substrate.registry)
            return encoder.output
        }.mapError(SubstrateRpcApiError.from)
    }
    
    func _try<R>(_ f: @escaping () throws -> R) -> SRpcApiResult<R> {
        return Result { try f() }.mapError(SubstrateRpcApiError.from)
    }
}

public typealias SRpcApiResult<R> = Result<R, SubstrateRpcApiError>
public typealias SRpcApiCallback<R> = (SRpcApiResult<R>) -> Void

public enum SubstrateRpcApiError: Error {
    case encoding(error: SEncodingError)
    case decoding(error: SDecodingError)
    case type(error: DTypeParsingError)
    case registry(error: TypeRegistryError)
    case unsupportedRuntimeVersion(UInt32)
    case rpc(error: RpcClientError)
    case unknown(error: Error)
    
    public static func from(error: Error) -> SubstrateRpcApiError {
        switch error {
        case let e as SEncodingError: return .encoding(error: e)
        case let e as SDecodingError: return .decoding(error: e)
        case let e as RpcClientError: return .rpc(error: e)
        case let e as DTypeParsingError: return .type(error: e)
        case let e as TypeRegistryError: return .registry(error: e)
        default: return .unknown(error: error)
        }
    }
}

public final class SubstrateRpcApiRegistry<S: SubstrateProtocol> {
    private var _apis: [String: Any] = [:]
    public internal(set) weak var substrate: S!
    
    public func getRpcApi<A>(_ t: A.Type) -> A where A: SubstrateRpcApi, A.S == S {
        if let api = _apis[A.id] as? A {
            return api
        }
        let api = A(substrate: substrate)
        _apis[A.id] = api
        return api
    }
}
