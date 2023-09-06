//
//  ExtrinsicManager.swift
//  
//
//  Created by Yehor Popovych on 17/08/2023.
//

import Foundation
import ScaleCodec

public protocol ExtrinsicDecoder {
    func extrinsic<C: Call & RuntimeDecodable, D: ScaleCodec.Decoder, Extra: ExtrinsicExtra>(
        from decoder: inout D, runtime: any Runtime
    ) throws -> Extrinsic<C, Extra>
    
    var version: UInt8 { get }
}

public protocol ExtrinsicManager<TConfig>: ExtrinsicDecoder {
    associatedtype TConfig: BasicConfig
    associatedtype TUnsignedParams
    associatedtype TUnsignedExtra: ExtrinsicExtra
    associatedtype TSigningParams: ExtraSigningParameters
    associatedtype TSigningExtra
    associatedtype TSignedExtra: ExtrinsicExtra
    
    func unsigned<C: Call, R: RootApi>(
        call: C, params: TUnsignedParams, for api: R
    ) async throws -> Extrinsic<C, TUnsignedExtra> where SBC<R.RC> == TConfig
    
    func encode<C: Call, E: ScaleCodec.Encoder>(unsigned extrinsic: Extrinsic<C, TUnsignedExtra>,
                                                in encoder: inout E,
                                                runtime: any Runtime) throws

    func params<C: Call, R: RootApi>(
        unsigned extrinsic: Extrinsic<C, TUnsignedExtra>,
        partial params: TSigningParams.TPartial,
        for api: R
    ) async throws -> TSigningParams where SBC<R.RC> == TConfig
    
    func payload<C: Call, R: RootApi>(
        unsigned extrinsic: Extrinsic<C, TUnsignedExtra>,
        params: TSigningParams, for api: R
    ) async throws -> ExtrinsicSignPayload<C, TSigningExtra> where SBC<R.RC> == TConfig
    
    func encode<C: Call, E: ScaleCodec.Encoder>(payload: ExtrinsicSignPayload<C, TSigningExtra>,
                                                in encoder: inout E,
                                                runtime: any Runtime) throws
    
    func decode<C: Call & RuntimeDecodable, D: ScaleCodec.Decoder>(
        payload decoder: inout D, runtime: any Runtime
    ) throws -> ExtrinsicSignPayload<C, TSigningExtra>
    
    func signed<C: Call>(payload: ExtrinsicSignPayload<C, TSigningExtra>,
                         address: SBT<TConfig>.Address,
                         signature: SBT<TConfig>.Signature,
                         runtime: any Runtime) throws -> Extrinsic<C, TSignedExtra>
    
    func encode<C: Call, E: ScaleCodec.Encoder>(signed extrinsic: Extrinsic<C, TSignedExtra>,
                                                in encoder: inout E,
                                                runtime: any Runtime) throws
    
    func decode<C: Call & RuntimeDecodable, D: ScaleCodec.Decoder>(
        from decoder: inout D, runtime: any Runtime
    ) throws -> AnyExtrinsic<C>
    
    func validate(runtime: any Runtime) throws
    
    static var version: UInt8 { get }
}

public extension ExtrinsicManager {
    typealias AnyExtrinsic<C: Call> = Extrinsic<C, Either<TUnsignedExtra, TSignedExtra>>
    
    var version: UInt8 { Self.version }
    
    func extrinsic<C: Call & RuntimeDecodable, D: ScaleCodec.Decoder, Extra: ExtrinsicExtra>(
        from decoder: inout D, runtime: any Runtime
    ) throws -> Extrinsic<C, Extra> {
        guard Extrinsic<C, Extra>.self == AnyExtrinsic<C>.self else {
            throw ExtrinsicCodingError.typeMismatch(expected: AnyExtrinsic<C>.self,
                                                    got: Extrinsic<C, Extra>.self)
        }
        let decoded: AnyExtrinsic<C> = try decode(from: &decoder, runtime: runtime)
        return decoded as! Extrinsic<C, Extra>
    }
}
