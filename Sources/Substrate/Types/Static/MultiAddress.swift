//
//  MultiAddress.swift
//  
//
//  Created by Yehor Popovych on 17/08/2023.
//

import Foundation
import ScaleCodec

public enum MultiAddress<Id, Index>: IdentifiableType
    where Index: CompactCodable & ValueRepresentable & IdentifiableType,
          Id: StaticAccountId
{
    case id(Id)
    case index(Index)
    case raw(Data)
    case address32(Data)
    case address20(Data)

    public var isId: Bool {
        switch self {
        case .id(_): return true
        default: return false
        }
    }
    
    public init(id: Id) {
        self = .id(id)
    }

    public init(index: Index) {
        self = .index(index)
    }
    
    public static func definition(in registry: TypeRegistry<TypeDefinition.TypeId>) -> TypeDefinition.Builder
    {
        .variant(variants: [.s(0, "Id", registry.def(Id.self)),
                            .s(1, "Index", registry.def(compact: Index.self)),
                            .s(2, "Raw", registry.def(Data.self, .dynamic)),
                            .s(3, "Address32", registry.def(Data.self, .fixed(32))),
                            .s(4, "Address20", registry.def(Data.self, .fixed(20)))])
    }
}

extension MultiAddress: Equatable where Id: Equatable, Index: Equatable {}
extension MultiAddress: Hashable where Id: Hashable, Index: Hashable {}

extension MultiAddress: ValueRepresentable {
    public func asValue(of type: TypeDefinition,
                        in runtime: any Runtime) throws -> Value<TypeDefinition>
    {
        try validate(as: type, in: runtime).get()
        guard case .variant(variants: let variants) = type.definition else {
            throw TypeError.wrongType(for: Self.self, type: type,
                                      reason: "Not a variant", .get())
        }
        switch self {
        case .id(let id):
            return try .variant(name: variants[0].name,
                                values: [id.asValue(of: *variants[0].fields[0].type,
                                                    in: runtime)],
                                type)
        case .index(let index):
            return try .variant(name: variants[1].name,
                                values: [index.asValue(of: *variants[1].fields[0].type,
                                                       in: runtime)],
                                type)
        case .address20(let data):
            return try .variant(name: variants[2].name,
                                values: [data.asValue(of: *variants[2].fields[0].type,
                                                      in: runtime)],
                                type)
        case .raw(let data):
            return try .variant(name: variants[3].name,
                                values: [data.asValue(of: *variants[3].fields[0].type,
                                                      in: runtime)],
                                type)
        case .address32(let data):
            return try .variant(name: variants[4].name,
                                values: [data.asValue(of: *variants[4].fields[0].type,
                                                      in: runtime)],
                                type)
        }
    }
}

extension MultiAddress: VoidValueRepresentable where
    Id: VoidValueRepresentable, Index: VoidValueRepresentable
{
    public func asValue() -> Value<Void> {
        switch self {
        case .id(let id): return .variant(name: "Id", values: [id.asValue()])
        case .index(let index): return .variant(name: "Index", values: [index.asValue()])
        case .address20(let data): return .variant(name: "Address20", values: [data.asValue()])
        case .raw(let data): return .variant(name: "Raw", values: [data.asValue()])
        case .address32(let data): return .variant(name: "Address32", values: [data.asValue()])
        }
    }
}

extension MultiAddress: StaticAddress {
    public typealias TAccountId = Id
    
    public init(accountId: Id, runtime: Runtime) throws {
        self.init(id: accountId)
    }
}

extension MultiAddress: RuntimeCodable {
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: any Runtime) throws {
        let type = try decoder.decode(.enumCaseId)
        switch type {
        case 0: self = try .id(runtime.decode(account: Id.self, from: &decoder))
        case 1: self = try .index(decoder.decode(.compact))
        case 2: self = try .raw(decoder.decode())
        case 3: self = try .address32(decoder.decode(.fixed(32)))
        case 4: self = try .address20(decoder.decode(.fixed(20)))
        default: throw decoder.enumCaseError(for: type)
        }
    }

    public func encode<E: ScaleCodec.Encoder>(in encoder: inout E, runtime: any Runtime) throws {
        switch self {
        case .id(let id):
            try encoder.encode(0, .enumCaseId)
            try runtime.encode(account: id, in: &encoder)
        case .index(let index):
            try encoder.encode(1, .enumCaseId)
            try encoder.encode(index, .compact)
        case .raw(let data):
            try encoder.encode(2, .enumCaseId)
            try encoder.encode(data)
        case .address32(let data):
            try encoder.encode(3, .enumCaseId)
            try encoder.encode(data, .fixed(32))
        case .address20(let data):
            try encoder.encode(4, .enumCaseId)
            try encoder.encode(data, .fixed(20))
        }
    }
}

extension MultiAddress: CustomStringConvertible {
    public var description: String {
        switch self {
        case .id(let acc): return "\(acc)"
        case .index(let index): return "\(index)"
        case .raw(let raw): return raw.hex()
        case .address20(let raw): return raw.hex()
        case .address32(let raw): return raw.hex()
        }
    }
}
