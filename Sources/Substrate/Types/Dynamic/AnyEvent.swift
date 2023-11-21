//
//  AnyEvent.swift
//  
//
//  Created by Yehor Popovych on 17/08/2023.
//

import Foundation
import ScaleCodec

public struct AnyEvent: Event, RuntimeDynamicDecodable, ValidatableType, CustomStringConvertible {
    public let pallet: String
    public let name: String
    
    public let params: Value<TypeDefinition>
    
    public init(name: String, pallet: String, params: Value<TypeDefinition>) {
        self.pallet = pallet
        self.name = name
        self.params = params
    }
    
    public init<D: ScaleCodec.Decoder>(from decoder: inout D,
                                       as type: TypeDefinition,
                                       runtime: Runtime) throws
    {
        var value = try Value(from: &decoder, as: type, runtime: runtime)
        let pallet: String
        switch value.value {
        case .variant(.sequence(name: let name, values: let values)):
            guard values.count == 1 else {
                throw FrameTypeError.wrongFieldsCount(for: "AnyEvent", expected: 1,
                                                      got: values.count, .get())
            }
            pallet = name
            value = values.first!
        case .variant(.map(name: let name, fields: let fields)):
            guard fields.count == 1 else {
                throw FrameTypeError.wrongFieldsCount(for: "AnyEvent", expected: 1,
                                                      got: fields.count, .get())
            }
            pallet = name
            value = fields.values.first!
        default: throw FrameTypeError.paramMismatch(for: "AnyEvent",
                                                    index: 0,
                                                    expected: "Value.Variant",
                                                    got: value.description, .get())
        }
        switch value.value {
        case .variant(.sequence(name: let name, values: let values)):
            self.init(name: name,
                      pallet: pallet,
                      params: Value(value: .sequence(values), context: value.context))
        case .variant(.map(name: let name, fields: let fields)):
            self.init(name: name,
                      pallet: pallet,
                      params: Value(value: .map(fields), context: value.context))
        default: throw FrameTypeError.paramMismatch(for: "AnyEvent: \(pallet)",
                                                    index: 0,
                                                    expected: "Value.Variant",
                                                    got: value.description, .get())
        }
    }
    
    public static func fetchEventData<D: ScaleCodec.Decoder>(
        from decoder: inout D, runtime: any Runtime, type: TypeDefinition
    ) throws -> (name: String, pallet: String, data: Data) {
        let size = try Value<Void>.calculateSize(in: decoder, for: type)
        let hBytes = try decoder.peek(count: 2)
        guard let header = runtime.resolve(eventName: hBytes[1], pallet: hBytes[0]) else {
            throw FrameTypeError.typeInfoNotFound(for: "Event", index: hBytes[1],
                                                  frame: hBytes[0], .get())
        }
        return try (name: header.name, pallet: header.pallet, data: decoder.read(count: size))
    }
    
    public static func validate(as type: TypeDefinition,
                                in runtime: any Runtime) -> Result<Void, TypeError>
    {
        guard case .variant(variants: let vars) = type.definition else {
            return .failure(.wrongType(for: Self.self,
                                       type: type,
                                       reason: "Isn't variant", .get()))
        }
        return vars.voidErrorMap { vart in
            guard vart.fields.count == 1 else {
                return .failure(.wrongVariantFieldsCount(for: Self.self,
                                                         variant: vart.name,
                                                         expected: 1, type: type, .get()))
            }
            guard case .variant(_) = vart.fields[0].type.definition else {
                return .failure(.wrongType(for: Self.self,
                                           type: *vart.fields[0].type,
                                           reason: "Child type isn't variant", .get()))
            }
            return .success(())
        }
    }
    
    public var description: String {
        "\(pallet).\(name)(\(params))"
    }
}
