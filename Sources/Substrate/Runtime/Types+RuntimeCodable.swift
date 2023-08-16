//
//  Types+RuntimeCodable.swift
//  
//
//  Created by Yehor Popovych on 10/10/20.
//

import Foundation
import ScaleCodec
import Numberick

extension Bool: RuntimeCodable, RuntimeDynamicCodable {}
extension Data: RuntimeCodable, RuntimeDynamicCodable {}
extension Int8: RuntimeCodable, RuntimeDynamicCodable {}
extension Int16: RuntimeCodable, RuntimeDynamicCodable {}
extension Int32: RuntimeCodable, RuntimeDynamicCodable {}
extension Int64: RuntimeCodable, RuntimeDynamicCodable {}
extension UInt8: RuntimeCodable, RuntimeDynamicCodable {}
extension UInt16: RuntimeCodable, RuntimeDynamicCodable {}
extension UInt32: RuntimeCodable, RuntimeDynamicCodable {}
extension UInt64: RuntimeCodable, RuntimeDynamicCodable {}
extension String: RuntimeCodable, RuntimeDynamicCodable {}
extension Compact: RuntimeCodable, RuntimeDynamicCodable {}
extension NBKDoubleWidth: RuntimeCodable, RuntimeDynamicCodable {}

extension CaseIterable where Self: Equatable & ScaleCodec.Encodable, Self.AllCases.Index == Int {
    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E, runtime: Runtime) throws {
        try encode(in: &encoder)
    }
}

extension CaseIterable where Self: Equatable & ScaleCodec.Decodable, Self.AllCases.Index == Int {
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
        try self.init(from: &decoder)
    }
}

extension Optional: RuntimeEncodable where Wrapped: RuntimeEncodable {
    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E, runtime: Runtime) throws {
        try encode(in: &encoder) { val, enc in
            try val.encode(in: &enc, runtime: runtime)
        }
    }
}

extension Optional: RuntimeDecodable where Wrapped: RuntimeDecodable {
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
        self = try Optional<Wrapped>(from: &decoder) { dec in
             try Wrapped(from: &dec, runtime: runtime)
        }
    }
}

extension Array: RuntimeEncodable where Element: RuntimeEncodable {
    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E, runtime: Runtime) throws {
        try encode(in: &encoder) { val, enc in
            try val.encode(in: &enc, runtime: runtime)
        }
    }
}

extension Array: RuntimeDecodable where Element: RuntimeDecodable {
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
        try self.init(from: &decoder) { dec in
            try Element(from: &dec, runtime: runtime)
        }
    }
}

extension Set: RuntimeEncodable where Element: RuntimeEncodable {
    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E, runtime: Runtime) throws {
        try encode(in: &encoder) { val, enc in
            try val.encode(in: &enc, runtime: runtime)
        }
    }
}

extension Set: RuntimeDecodable where Element: RuntimeDecodable {
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
        try self.init(from: &decoder) { dec in
            try Element(from: &dec, runtime: runtime)
        }
    }
}

extension Dictionary: RuntimeEncodable where Key: RuntimeEncodable, Value: RuntimeEncodable {
    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E, runtime: Runtime) throws {
        try encode(in: &encoder, lwriter: { try $0.encode(in: &$1, runtime: runtime) }) { val, enc in
            try val.encode(in: &enc, runtime: runtime)
        }
    }
}

extension Dictionary: RuntimeDecodable where Key: RuntimeDecodable, Value: RuntimeDecodable
{
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
        try self.init(from: &decoder, lreader: { try Key(from: &$0, runtime: runtime) }) { dec in
            try Value(from: &dec, runtime: runtime)
        }
    }
}

extension Result: RuntimeEncodable where Success: RuntimeEncodable, Failure: RuntimeEncodable {
    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E, runtime: Runtime) throws {
        try encode(in: &encoder, lwriter: { try $0.encode(in: &$1, runtime: runtime) }) { err, enc in
            try err.encode(in: &enc, runtime: runtime)
        }
    }
}

extension Result: RuntimeDecodable where Success: RuntimeDecodable, Failure: RuntimeDecodable {
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
        try self.init(from: &decoder, lreader: { try Success(from: &$0, runtime: runtime) }) { dec in
            try Failure(from: &dec, runtime: runtime)
        }
    }
}
