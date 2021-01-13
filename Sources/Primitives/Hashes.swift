//
//  Hashes.swift
//  
//
//  Created by Yehor Popovych on 10/8/20.
//

import Foundation
import ScaleCodec

public protocol Hash: ScaleFixedData, ScaleDynamicCodable {}

public struct Hash160: Hash {
    let data: Data
    
    public init(_ data: Data) {
        precondition(
            data.count == Hash160.fixedBytesCount,
            "Wrong data length: \(data.count) expected \(Hash160.fixedBytesCount)"
        )
        self.data = data
    }
    
    public init(decoding data: Data) throws {
        self.data = data
    }
    
    public func encode() throws -> Data {
        return self.data
    }
    
    public static var fixedBytesCount: Int = 20
}

public struct Hash256: Hash {
    let data: Data
    
    public init(_ data: Data) {
        precondition(
            data.count == Hash256.fixedBytesCount,
            "Wrong data length: \(data.count) expected \(Hash256.fixedBytesCount)"
        )
        self.data = data
    }
    
    public init(decoding data: Data) throws {
        self.data = data
    }
    
    public func encode() throws -> Data {
        return self.data
    }
    
    public static var fixedBytesCount: Int = 32
}

public struct Hash512: Hash {
    let data: Data
    
    public init(_ data: Data) {
        precondition(
            data.count == Hash512.fixedBytesCount,
            "Wrong data length: \(data.count) expected \(Hash512.fixedBytesCount)"
        )
        self.data = data
    }
    
    public init(decoding data: Data) throws {
        self.data = data
    }
    
    public func encode() throws -> Data {
        return self.data
    }
    
    public static var fixedBytesCount: Int = 64
}
