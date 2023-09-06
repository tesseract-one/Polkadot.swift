//
//  AnyCallErrors.swift
//  
//
//  Created by Yehor Popovych on 17/08/2023.
//

import Foundation
import ScaleCodec

public struct AnyTransactionValidityError: CallError, CustomDebugStringConvertible {
    public typealias DecodingContext = RuntimeDynamicSwiftCodableContext
    
    public let value: Value<NetworkType.Id>
    
    public init(value: Value<NetworkType.Id>) {
        self.value = value
    }
    
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, as info: NetworkType.Info, runtime: Runtime) throws {
        let value = try Value<NetworkType.Id>(from: &decoder, as: info, runtime: runtime)
        self.init(value: value)
    }
    
    public init(from decoder: Swift.Decoder, as info: NetworkType.Info, runtime: Runtime) throws {
        let value = try Value<NetworkType.Id>(from: decoder, as: info, runtime: runtime)
        self.init(value: value)
    }
    
    public static func validate(runtime: any Runtime,
                                type info: NetworkType.Info) -> Result<Void, TypeError> {
        .success(())
    }
    
    public var debugDescription: String {
        "TransactionValidityError: \(value)"
    }
}

public struct AnyDispatchError: SomeDispatchError, VariantValidatableType, CustomDebugStringConvertible {
    public typealias TModuleError = ModuleError
    public typealias DecodingContext = RuntimeDynamicSwiftCodableContext
    
    public let value: Value<NetworkType.Id>
    private let _runtime: any Runtime
    
    @inlinable
    public var isModuleError: Bool { value.variant?.name.contains("Module") ?? false }
    
    public var moduleError: TModuleError { get throws {
        let fields = value.variant!.values
        guard fields.count == 1 else {
            throw FrameTypeError.wrongFieldsCount(for: "DispatchError.\(value.variant!.name)",
                                                  expected: 1, got: fields.count, .get())
        }
        guard let values = fields[0].sequence else {
            throw FrameTypeError.paramMismatch(for: "DispatchError.\(value.variant!.name)",
                                               index: 0, expected: "Composite",
                                               got: fields[0].description, .get())
        }
        return try ModuleError(values: values, runtime: _runtime)
    }}
    
    public init<D: ScaleCodec.Decoder>(from decoder: inout D, as info: NetworkType.Info, runtime: Runtime) throws {
        let value = try Value<NetworkType.Id>(from: &decoder, as: info, runtime: runtime)
        guard value.variant != nil else {
            throw ScaleCodec.DecodingError.typeMismatch(
                Value<NetworkType.Id>.self,
                .init(path: decoder.path, description: "Decoded non-variant value")
            )
        }
        self.value = value
        self._runtime = runtime
    }
    
    public init(from decoder: Swift.Decoder, as info: NetworkType.Info, runtime: Runtime) throws {
        let value = try Value<NetworkType.Id>(from: decoder, as: info, runtime: runtime)
        guard value.variant != nil else {
            throw Swift.DecodingError.typeMismatch(
                Value<NetworkType.Id>.self,
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Decoded non-variant value")
            )
        }
        self.value = value
        self._runtime = runtime
    }
    
    public static func validate(info: TypeInfo, type tinfo: NetworkType.Info,
                                runtime: Runtime) -> Result<Void, TypeError>
    {
        guard let module = info.first(where: { $0.name.contains("Module") }) else {
            return .failure(.variantNotFound(for: Self.self,
                                             variant: "*Module*",
                                             type: tinfo.type, .get()))
        }
        guard module.fields.count == 1 else {
            return .failure(.wrongValuesCount(for: Self.self, expected: 1,
                                              type: tinfo.type, .get()))
        }
        return TModuleError.validate(runtime: runtime, type: module.fields[0].type)
    }
    
    public var debugDescription: String {
        "DispatchError: \(value)"
    }
}
