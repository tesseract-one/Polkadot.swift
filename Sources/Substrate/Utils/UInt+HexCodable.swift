//
//  UInt+HexCodable.swift
//  
//
//  Created by Yehor Popovych on 06.01.2023.
//

import Foundation
import ScaleCodec
import Numberick

public struct TrimmedHex: Swift.Codable {
    public struct InitError: Error {
        public let desc: String
    }
    
    public let data: Data
    
    public init(data: Data) { self.data = data }
    
    public init(string: String) throws {
        guard string != "0x0" else {
            self.init(data: Data())
            return
        }
        var string = string
        if string.hasPrefix("0x") {
            string.removeFirst(2)
        }
        if string.count % 2 == 1 {
            string.insert("0", at: string.startIndex)
        }
        guard let data = Data(hex: string) else {
            throw InitError(desc: "Bad hex value \(string)")
        }
        self.init(data: data)
    }
    
    public var string: String {
        guard !data.isEmpty else { return "0x0" }
        var hex = data.hex(prefix: false)
        if (hex[hex.startIndex] == "0") {
            hex.remove(at: hex.startIndex)
        }
        hex.insert(contentsOf: "0x", at: hex.startIndex)
        return hex
    }
    
    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            try self.init(string: string)
        } catch let e as InitError {
            throw Swift.DecodingError.dataCorruptedError(in: container,
                                                         debugDescription: e.desc)
        }
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

public struct UIntHex<T: UnsignedInteger> {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

extension UIntHex: Swift.Decodable where T: DataInitalizable {
    public init(string: String) throws {
        let hex = try TrimmedHex(string: string)
        guard !hex.data.isEmpty else {
            self.init(0)
            return
        }
        guard let val = T(data: hex.data, littleEndian: false, trimmed: true) else {
            throw TrimmedHex.InitError(desc: "Can't initialize \(T.self) from \(string)")
        }
        self.init(val)
    }
    
    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            try self.init(string: string)
        } catch let e as TrimmedHex.InitError {
            throw Swift.DecodingError.dataCorruptedError(in: container,
                                                         debugDescription: e.desc)
        }
    }
}

extension UIntHex: Swift.Encodable where T: DataSerializable {
    public func encode(to encoder: Swift.Encoder) throws {
        let data = value == 0
            ? Data() : value.data(littleEndian: false, trimmed: true)
        try TrimmedHex(data: data).encode(to: encoder)
    }
}

public struct HexOrNumber<T: UnsignedInteger> {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

extension HexOrNumber: Swift.Decodable where T: Swift.Decodable & DataInitalizable {
    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(T.self) {
            self.init(value)
        } else {
            self.init(try container.decode(UIntHex<T>.self).value)
        }
    }
}

extension HexOrNumber: Swift.Encodable where T: Swift.Encodable & DataSerializable {
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        if UInt64(clamping: value) > JSONEncoder.maxSafeInteger {
            try container.encode(UIntHex(value))
        } else {
            try container.encode(value)
        }
    }
}

public extension JSONEncoder {
    @inlinable
    static var maxSafeInteger: UInt64 { (1 << 53) - 1 }
}

extension Compact: Swift.Decodable where T.UI: DataInitalizable & Swift.Decodable {
    public init(from decoder: Swift.Decoder) throws {
        let uint = try HexOrNumber<T.UI>(from: decoder)
        self.init(T(uint: uint.value))
    }
}

extension Compact: Swift.Encodable where T.UI: DataSerializable & Swift.Encodable {
    public func encode(to encoder: Swift.Encoder) throws {
        try HexOrNumber(value.uint).encode(to: encoder)
    }
}

extension NBKDoubleWidth: Swift.Codable where Self: UnsignedInteger {
    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(UInt64.self) {
            self.init(value)
        } else {
            self.init(try container.decode(UIntHex<Self>.self).value)
        }
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        if UInt64(clamping: self) > JSONEncoder.maxSafeInteger {
            try container.encode(UIntHex(self))
        } else {
            try container.encode(UInt64(self))
        }
    }
}
