//
//  Types+ValueRepresentable.swift
//  
//
//  Created by Yehor Popovych on 17.01.2023.
//

import Foundation
import ScaleCodec
import Numberick

public extension FixedWidthInteger where Self: ValidatableTypeDynamic {
    func asValue() -> Value<Void> {
        Self.isSigned ?  .int(Int256(self)) : .uint(UInt256(self))
    }
    
    func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        try validate(as: type, in: runtime).get()
        return Self.isSigned ?  .int(Int256(self), type) : .uint(UInt256(self), type)
    }
}

extension UInt8: ValueRepresentable, VoidValueRepresentable {}
extension UInt16: ValueRepresentable, VoidValueRepresentable {}
extension UInt32: ValueRepresentable, VoidValueRepresentable {}
extension UInt64: ValueRepresentable, VoidValueRepresentable {}
extension UInt: ValueRepresentable, VoidValueRepresentable {}
extension NBKDoubleWidth: ValueRepresentable, VoidValueRepresentable {}
extension Int8: ValueRepresentable, VoidValueRepresentable {}
extension Int16: ValueRepresentable, VoidValueRepresentable {}
extension Int32: ValueRepresentable, VoidValueRepresentable {}
extension Int64: ValueRepresentable, VoidValueRepresentable {}
extension Int: ValueRepresentable, VoidValueRepresentable {}

extension Value: ValueRepresentable, VoidValueRepresentable {
    public func asValue() -> Value<Void> { mapContext{_ in} }
    
    public func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        try validate(as: type, in: runtime).get()
        return mapContext{_ in type}
    }
}

extension Bool: ValueRepresentable, VoidValueRepresentable {
    public func asValue() -> Value<Void> { .bool(self) }
    
    public func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        try validate(as: type, in: runtime).get()
        return .bool(self, type)
    }
}

extension String: ValueRepresentable, VoidValueRepresentable {
    public func asValue() -> Value<Void> { .string(self) }
    
    public func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        try validate(as: type, in: runtime).get()
        return .string(self, type)
    }
}

extension Data: ValueRepresentable, VoidValueRepresentable {
    public func asValue() -> Value<Void> { .bytes(self) }
    
    public func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        try validate(as: type, in: runtime).get()
        return .bytes(self, type)
    }
}

extension Compact: ValueRepresentable, VoidValueRepresentable {
    public func asValue() -> Value<Void> { .uint(UInt256(value.uint)) }
    
    public func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        try validate(as: type, in: runtime).get()
        return .uint(UInt256(value.uint), type)
    }
}

extension Character: ValueRepresentable, VoidValueRepresentable {
    public func asValue() -> Value<Void> { .char(self) }
    
    public func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        try validate(as: type, in: runtime).get()
        return .char(self, type)
    }
}

public extension Collection where Element == ValueRepresentable {
    func validate(as type: TypeDefinition, in runtime: any Runtime) -> Result<Void, TypeError> {
        switch type.flatten().definition {
        case .array(count: let c, of: let eType):
            guard count == c else {
                return .failure(.wrongValuesCount(for: self, expected: count,
                                                  type: type, .get()))
            }
            fallthrough
        case .sequence(of: let eType):
            return voidErrorMap { $0.validate(as: *eType, in: runtime).map{_ in} }
        case .composite(fields: let fields):
            guard count == fields.count else {
                return .failure(.wrongValuesCount(for: self, expected: count,
                                                  type: type, .get()))
            }
            return zip(self, fields).voidErrorMap { v, f in
                v.validate(as: *f.type, in: runtime).map {_ in}
            }
        default:
            return .failure(.wrongType(for: self, type: type,
                                       reason: "Isn't collection", .get()))
        }
    }
    
    func asValue(of type: TypeDefinition, in runtime: any Runtime) throws -> Value<TypeDefinition> {
        switch type.flatten().definition {
        case .array(count: let count, of: let eType):
            guard count == self.count else {
                throw TypeError.wrongValuesCount(for: self,
                                                 expected: self.count,
                                                 type: type, .get())
            }
            fallthrough
        case .sequence(of: let eType):
            let mapped = try map{ try $0.asValue(of: *eType, in: runtime) }
            return .sequence(mapped, type)
        case .composite(fields: let fields):
            guard fields.count == count else {
                throw TypeError.wrongValuesCount(for: self,
                                                 expected: count,
                                                 type: type, .get())
            }
            let arr = try zip(self, fields).map { try $0.asValue(of: *$1.type, in: runtime) }
            return .sequence(arr, type)
        default:
            throw TypeError.wrongType(for: self, type: type,
                                      reason: "Isn't collection", .get())
        }
    }
}

public extension Sequence where Element == VoidValueRepresentable {
    func asValue() -> Value<Void> {.sequence(self)}
}

extension Array: ValueRepresentable, ValidatableTypeDynamic where Element == ValueRepresentable {}
extension Array: VoidValueRepresentable where Element == VoidValueRepresentable {}

extension Dictionary: ValueRepresentable, ValidatableTypeDynamic where Key == String,
                                                                       Value == ValueRepresentable
{
    public func validate(as type: TypeDefinition, in runtime: any Runtime) -> Result<Void, TypeError> {
        switch type.flatten().definition {
        case .composite(fields: let fields):
            return fields.voidErrorMap { field in
                guard let key = field.name else {
                    return .failure(.wrongType(for: self, type: type,
                                               reason: "field name is nil", .get()))
                }
                return self[key].validate(as: *field.type, in: runtime).map{_ in}
            }
        // Variant can be represented as ["Name": Value]
        case .variant(variants: let variants):
            guard count == 1 else {
                return .failure(.wrongType(for: self, type: type,
                                           reason: "count != 1 for variant", .get()))
            }
            guard let variant = variants.first(where: { $0.name == first!.key }) else {
                return .failure(.variantNotFound(for: self,
                                                 variant: first!.key,
                                                 type: type, .get()))
            }
            // this will allow array/dictionary as a parameter
            if variant.fields.count == 1 {
                return first!.value.validate(as: *variant.fields[0].type,
                                             in: runtime).map{_ in}
            }
            // unpack fields
            switch first!.value {
            case let arr as Array<ValueRepresentable>:
                guard variant.fields.count == arr.count else {
                    return .failure(.wrongValuesCount(for: self,
                                                      expected: variant.fields.count,
                                                      type: type, .get()))
                }
                return zip(variant.fields, arr).voidErrorMap { field, elem in
                    elem.validate(as: *field.type, in: runtime).map{_ in}
                }
            case let dict as Dictionary<String, ValueRepresentable>:
                return variant.fields.voidErrorMap { field in
                    guard let key = field.name else {
                        return .failure(.wrongType(for: self, type: type,
                                                   reason: "field name is nil", .get()))
                    }
                    return dict[key].validate(as: *field.type, in: runtime).map{_ in}
                }
            default: return .failure(.wrongType(for: self, type: type,
                                                reason: "Can't be a variant type", .get()))
            }
        default:
            return .failure(.wrongType(for: self, type: type,
                                       reason: "Isn't map", .get()))
        }
    }
    
    public func asValue(of type: TypeDefinition,
                        in runtime: Runtime) throws -> Substrate.Value<TypeDefinition>
    {
        switch type.flatten().definition {
        case .composite(fields: let fields):
            let map = try fields.map { field in
                guard let key = field.name else {
                    throw TypeError.wrongType(for: self, type: type,
                                              reason: "field name is nil", .get())
                }
                return try (key, self[key].asValue(of: *field.type, in: runtime))
            }
            return .map(Dictionary<_,_>(uniqueKeysWithValues: map), type)
        // Variant can be represented as ["Name": Value]
        case .variant(variants: let variants):
            guard count == 1 else {
                throw TypeError.wrongType(for: self, type: type,
                                          reason: "count != 1 for variant", .get())
            }
            guard let variant = variants.first(where: { $0.name == first!.key }) else {
                throw TypeError.variantNotFound(for: self, variant: first!.key,
                                                type: type, .get())
            }
            // this will allow array/dictionary as a parameter
            if variant.fields.count == 1 {
                let val = try first!.value.asValue(of: *variant.fields.first!.type,
                                                   in: runtime)
                if let name = variant.fields.first?.name {
                    return .variant(name: variant.name, fields: [name: val], type)
                } else {
                    return .variant(name: variant.name, values: [val], type)
                }
            }
            // unpack fields
            switch first!.value {
            case let arr as Array<ValueRepresentable>:
                guard arr.count == variant.fields.count else {
                    throw TypeError.wrongValuesCount(for: self,
                                                     expected: variant.fields.count,
                                                     type: type, .get())
                }
                let seq = try zip(arr, variant.fields).map { el, fld in
                    try el.asValue(of: *fld.type, in: runtime)
                }
                return .variant(name: variant.name, values: seq, type)
            case let dict as Dictionary<String, ValueRepresentable>:
                let map = try variant.fields.map { field in
                    guard let key = field.name else {
                        throw TypeError.wrongType(for: self, type: type,
                                                  reason: "field name is nil", .get())
                    }
                    return try (key, dict[key].asValue(of: *field.type, in: runtime))
                }
                return .variant(name: variant.name,
                                fields: Dictionary<_,_>(uniqueKeysWithValues: map), type)
            default: throw TypeError.wrongType(for: self, type: type,
                                               reason: "Can't be a variant type", .get())
            }
        default:
            throw TypeError.wrongType(for: self, type: type,
                                      reason: "Isn't map", .get())
        }
    }
}

extension Dictionary: VoidValueRepresentable where Key: StringProtocol, Value == VoidValueRepresentable {
    public func asValue() -> Substrate.Value<Void> {
        .map(map { (String($0.key), $0.value.asValue()) })
    }
}

extension Optional: ValueRepresentable, ValidatableTypeDynamic where Wrapped == ValueRepresentable {
    public func validate(as type: TypeDefinition,
                         in runtime: any Runtime) -> Result<Void, TypeError>
    {
        if let value = self {
            if let field = type.asOptional() {
                return value.validate(as: *field.type, in: runtime).map{_ in}
            }
            return value.validate(as: type, in: runtime)
        }
        return type.asOptional() != nil
            ? .success(())
            : .failure(.wrongType(for: Self.self, type: type,
                                  reason: "Isn't optional", .get()))
    }
    
    public func asValue(of type: TypeDefinition,
                        in runtime: any Runtime) throws -> Value<TypeDefinition>
    {
        if let svalue = self {
            if let field = type.asOptional() {
                let value = try svalue.asValue(of: *field.type, in: runtime)
                return .variant(name: "Some", values: [value], type)
            }
            return try svalue.asValue(of: type, in: runtime)
        }
        guard type.asOptional() != nil else {
            throw TypeError.wrongType(for: Self.self, type: type,
                                      reason: "Isn't optional", .get())
        }
        return .variant(name: "None", values: [], type)
    }
}

extension Optional: VoidValueRepresentable where Wrapped == VoidValueRepresentable {
    public func asValue() -> Value<Void> {
        switch self {
        case .some(let val): return .variant(name: "Some", values: [val.asValue()])
        case .none: return .variant(name: "None", values: [])
        }
    }
}

extension Either: ValueRepresentable, ValidatableTypeDynamic
    where Left == ValueRepresentable, Right == ValueRepresentable
{
    public func validate(as type: TypeDefinition, in runtime: Runtime) -> Result<Void, TypeError> {
        guard let result = type.asResult() else {
            return .failure(.wrongType(for: self, type: type,
                                       reason: "Isn't Result", .get()))
        }
        switch self {
        case .left(let err):
            return err.validate(as: *result.err.type, in: runtime).map{_ in}
        case .right(let ok):
            return ok.validate(as: *result.ok.type, in: runtime).map{_ in}
        }
    }
    
    
    public func asValue(of type: TypeDefinition,
                        in runtime: any Runtime) throws -> Value<TypeDefinition>
    {
        guard let result = type.asResult() else {
            throw TypeError.wrongType(for: self, type: type,
                                      reason: "Isn't Result", .get())
        }
        switch self {
        case .left(let err):
            return try .variant(name: "Err",
                                values: [err.asValue(of: *result.err.type,
                                                     in: runtime)], type)
        case .right(let ok):
            return try .variant(name: "Ok",
                                values: [ok.asValue(of: *result.ok.type,
                                                    in: runtime)], type)
        }
    }
}

extension Either: VoidValueRepresentable where
    Left == VoidValueRepresentable, Right == VoidValueRepresentable
{
    public func asValue() -> Value<Void> {
        switch self {
        case .left(let err):
            return .variant(name: "Err", values: [err.asValue()])
        case .right(let ok):
            return .variant(name: "Ok", values: [ok.asValue()])
        }
    }
}
