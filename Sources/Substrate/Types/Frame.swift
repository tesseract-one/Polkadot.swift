//
//  Frame.swift
//  
//
//  Created by Yehor Popovych on 31/08/2023.
//

import Foundation

public protocol Frame: RuntimeValidatableType {
    var name: String { get }
    static var name: String { get }
    
    var calls: [PalletCall.Type] { get }
    var events: [PalletEvent.Type] { get }
    var errors: [StaticPalletError.Type] { get }
    var storageKeys: [any PalletStorageKey.Type] { get }
    var constants: [any StaticConstant.Type] { get }
}

public extension Frame {
    @inlinable var name: String { Self.name }
    
    var calls: [PalletCall.Type] { [] }
    var events: [PalletEvent.Type] { [] }
    var errors: [StaticPalletError.Type] { [] }
    var storageKeys: [any PalletStorageKey.Type] { [] }
    var constants: [any StaticConstant.Type] { [] }
    
    func validate(runtime: any Runtime) -> Result<Void, FrameTypeError> {
        calls.voidErrorMap { $0.validate(runtime: runtime) }
            .flatMap { events.voidErrorMap { $0.validate(runtime: runtime) } }
            .flatMap { storageKeys.voidErrorMap { $0.validate(runtime: runtime) } }
            .flatMap { constants.voidErrorMap { $0.validate(runtime: runtime) } }
            .flatMap { errors.voidErrorMap { $0.validate(runtime: runtime) }}
    }
}

public protocol RuntimeApiFrame: RuntimeValidatableType {
    var name: String { get }
    static var name: String { get }
    
    var calls: [any StaticRuntimeCall.Type] { get }
}

public extension RuntimeApiFrame {
    @inlinable var name: String { Self.name }
    
    func validate(runtime: any Runtime) -> Result<Void, FrameTypeError> {
        calls.voidErrorMap { $0.validate(runtime: runtime) }
    }
}

public protocol FrameCall: PalletCall {
    associatedtype TFrame: Frame
}

public extension FrameCall {
    static var pallet: String { TFrame.name }
}

public protocol FrameEvent: PalletEvent {
    associatedtype TFrame: Frame
}

public extension FrameEvent {
    static var pallet: String { TFrame.name }
}

public protocol FrameStorageKey: PalletStorageKey {
    associatedtype TFrame: Frame
}

public extension FrameStorageKey {
    static var pallet: String { TFrame.name }
}

public protocol FrameConstant: StaticConstant {
    associatedtype TFrame: Frame
}

public extension FrameConstant {
    static var pallet: String { TFrame.name }
}

public protocol FrameError: StaticPalletError {
    associatedtype TFrame: Frame
}

public extension FrameError {
    static var pallet: String { TFrame.name }
}

public protocol RuntimeApiFrameCall: StaticRuntimeCall {
    associatedtype TApi: RuntimeApiFrame
}

public extension RuntimeApiFrameCall {
    static var api: String { TApi.name }
}

public extension Configs {
    struct BaseSystemFrame<C: Config>: RuntimeValidatableType {
        public func validate(runtime: Runtime) -> Result<Void, FrameTypeError> {
            ST<C>.ExtrinsicFailureEvent.validate(runtime: runtime).flatMap {
                EventsStorageKey<ST<C>.BlockEvents>.validate(runtime: runtime)
            }.flatMap {
                if let config = C.self as? any BatchSupportedConfig.Type,
                   runtime.isBatchSupported
                {
                    return config.batchCalls.voidErrorMap { call in
                        call.validate(runtime: runtime)
                    }
                } else {
                    return .success(())
                }
            }
        }
        
        public init() {}
    }
    
    struct BaseRuntimeTransactionApi<C: Config>: RuntimeValidatableType {
        public func validate(runtime: any Runtime) -> Result<Void, FrameTypeError> {
            if runtime.metadata.version < 15 {
                return .success(())
            }
            let calls: [any StaticRuntimeCall.Type] = [
                TransactionQueryInfoRuntimeCall<ST<C>.RuntimeDispatchInfo>.self,
                TransactionQueryFeeDetailsRuntimeCall<ST<C>.FeeDetails>.self
            ]
            return calls.voidErrorMap { $0.validate(runtime: runtime) }
        }
        
        public init() {}
    }
}

public struct ExtrinsicEventsFrameFilter<R: RootApi, F: Frame>: ExtrinsicEventsFilter {
    public let blockEvents: ST<R.RC>.BlockEvents
    public let index: UInt32
    
    public init(blockEvents: ST<R.RC>.BlockEvents, index: UInt32) {
        self.blockEvents = blockEvents
        self.index = index
    }
    
    public static var pallet: String { F.name }
    
    public func _event<E: FrameEvent>(_: E.Type) -> ExtrinsicEventsEventFilter<R, E>
        where E.TFrame == F
    {
        _event()
    }
    public func _event<E: FrameEvent>() -> ExtrinsicEventsEventFilter<R, E>
        where E.TFrame == F
    {
        .init(blockEvents: blockEvents, index: index)
    }
}

public extension ExtrinsicEvents {
    @inlinable func _frame<F: Frame>() -> ExtrinsicEventsFrameFilter<R, F> {
        _filter()
    }
    @inlinable func _frame<F: Frame>(_: F.Type) -> ExtrinsicEventsFrameFilter<R, F> {
        _filter()
    }
}

public struct FrameStorageApi<R: RootApi, F: Frame>: StorageApi {
    public weak var api: R!
    public init(api: R) { self.api = api }
}

public struct FrameConstantsApi<R: RootApi, F: Frame>: ConstantsApi {
    public weak var api: R!
    public init(api: R) { self.api = api }
}

public struct FrameExtrinsicApi<R: RootApi, F: Frame>: ExtrinsicApi {
    public weak var api: R!
    public init(api: R) { self.api = api }
}

public struct FrameRuntimeCallApi<R: RootApi, F: RuntimeApiFrame>: RuntimeCallApi {
    public weak var api: R!
    public init(api: R) { self.api = api }
}

public extension ConstantsApiRegistry {
    func _frame<F: Frame>() -> FrameConstantsApi<R, F> { _api() }
    func _frame<F: Frame>(_: F.Type) -> FrameConstantsApi<R, F> { _api() }
}

public extension ExtrinsicApiRegistry {
    func _frame<F: Frame>() -> FrameExtrinsicApi<R, F> { _api() }
    func _frame<F: Frame>(_: F.Type) -> FrameExtrinsicApi<R, F> { _api() }
}

public extension StorageApiRegistry {
    func _frame<F: Frame>() -> FrameStorageApi<R, F> { _api() }
    func _frame<F: Frame>(_: F.Type) -> FrameStorageApi<R, F> { _api() }
}

public extension RuntimeCallApiRegistry {
    func _frame<F: RuntimeApiFrame>() -> FrameRuntimeCallApi<R, F> { _api() }
    func _frame<F: RuntimeApiFrame>(_: F.Type) -> FrameRuntimeCallApi<R, F> { _api() }
}
