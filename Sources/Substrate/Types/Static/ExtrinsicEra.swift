//
//  ExtrinsicEra.swift
//  
//
//  Created by Yehor Popovych on 10/12/20.
//

import Foundation
import ScaleCodec

public enum ExtrinsicEra: SomeExtrinsicEra, Default {
    case immortal
    case mortal(period: UInt64, phase: UInt64)
    
    public var isImmortal: Bool {
        switch self {
        case .immortal: return true
        default: return false
        }
    }
    
    // Create a new era based on a period (which should be a power of two between 4 and 65536 inclusive)
    // and a block number on which it should start (or, for long periods, be shortly after the start).
    //
    // If using `Era` in the context of `FRAME` runtime, make sure that `period`
    // does not exceed `BlockHashCount` parameter passed to `system` module, since that
    // prunes old blocks and renders transactions immediately invalid.
    public init(period: UInt64, current: UInt64) {
        let period = min(max(period._nextPowerOfTwo ?? (1 << 16), 4), 1 << 16)
        let phase = current % period
        let quantize_factor = max(1, (period >> 12))
        let quantized_phase = phase / quantize_factor * quantize_factor
        self = .mortal(period: period, phase: quantized_phase)
    }
    
    // Get the block number of the start of the era whose properties this object
    // describes that `current` belongs to.
    public func birth(current: UInt64) -> UInt64 {
        switch self {
        case .immortal: return 0
        case .mortal(period: let period, phase: let phase): return (max(current, phase) - phase) / period * period + phase
        }
    }

    // Get the block number of the first block at which the era has ended.
    public func death(current: UInt64) -> UInt64 {
        switch self {
        case .immortal: return UInt64.max
        case .mortal(period: let period, phase: _): return self.birth(current: current) + period
        }
    }
    
    public init?(b1: UInt8, b2: UInt8?) {
        if b1 == 0 {
            guard b2 == nil else { return nil }
            self = .immortal
        } else {
            guard let b2 = b2 else { return nil}
            let encoded = UInt64(b1) + UInt64(b2) << 8
            let period = UInt64(2) << (encoded % (1 << 4))
            let quantize_factor = max((period >> 12), 1)
            let phase = (encoded >> 4) * quantize_factor
            guard period >= 4 && phase < period else { return nil }
            self = .mortal(period: period, phase: phase)
        }
    }
    
    public func serialize() -> (UInt8, UInt8?) {
        switch self {
        case .immortal: return (0, nil)
        case .mortal(period: let period, phase: let phase):
            let quantize_factor = max((period >> 12), 1)
            let encoded = UInt16(min(max(period.trailingZeroBitCount - 1, 1), 15))
                | UInt16((phase / quantize_factor) << 4)
            return withUnsafeBytes(of: encoded.littleEndian) { buf in
                return (buf[0], buf[1])
            }
        }
    }
    
    public func blockHash<R: RootApi>(api: R) async throws -> R.RC.TBlock.THeader.THasher.THash {
        switch self {
        case .immortal:  return api.runtime.genesisHash
        case .mortal(period: _, phase: _):
            let currentBlock = try await api.client.block(header: nil,
                                                          runtime: api.runtime)!.number
            let birthBlock = self.birth(current: UInt64(currentBlock))
            return try await api.client.block(hash: R.RC.TBlock.THeader.TNumber(birthBlock),
                                              runtime: api.runtime)!
        }
    }
}

extension ExtrinsicEra: ScaleCodec.Codable {
    public init<D: ScaleCodec.Decoder>(from decoder: inout D) throws {
        let first: UInt8 = try decoder.decode()
        let val = first == 0
            ? Self(b1: first, b2: nil)
            : try Self(b1: first, b2: decoder.decode(UInt8.self))
        guard let val = val else {
            throw ScaleCodec.DecodingError.dataCorrupted(
                ScaleCodec.DecodingError.Context(
                    path: decoder.path,
                    description: "Invalid period and phase"
                )
            )
        }
        self = val
    }
    
    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E) throws {
        let data = serialize()
        try encoder.encode(data.0)
        if let second = data.1 {
            try encoder.encode(second)
        }
    }
}

extension ExtrinsicEra: RuntimeCodable {}

extension ExtrinsicEra: IdentifiableType {
    public static func definition(in registry: TypeRegistry<TypeDefinition.TypeId>) -> TypeDefinition.Builder
    {
        let u8def = registry.def(UInt8.self)
        return .variant(variants:
            [.e(0, "Immortal")] +
            Array((UInt8(1)...255).map{.s($0, "Mortal\($0)", u8def)})
        )
    }
}

extension ExtrinsicEra: ValueRepresentable {
    public func asValue(of type: TypeDefinition,
                        in runtime: any Runtime) throws -> Value<TypeDefinition>
    {
        try validate(as: type, in: runtime).get()
        guard case .variant(variants: let vars) = type.flatten().definition else {
            throw TypeError.wrongType(for: Self.self, type: type,
                                      reason: "Not a variant", .get())
        }
        let bodyType = vars[1].fields[0].type
        switch self {
        case .immortal: return .variant(name: "Immortal", values: [], type)
        case .mortal(period: _, phase: _):
            let (first, second) = self.serialize()
            return .variant(name: "Mortal\(first)", values: [.uint(UInt256(second!), *bodyType)], type)
        }
    }
}

extension UInt64 {
    fileprivate var _nextPowerOfTwo: UInt64? {
        let i = Self.bitWidth - self.leadingZeroBitCount
        guard i < 64 else { return nil }
        return 1 << i
    }
}
