//
//  TupleStorageKey.swift
//  
//
//  Created by Yehor Popovych on 28/07/2023.
//

import Foundation
import Tuples
import ScaleCodec

public protocol TupleStorageKeyHasherPair {
    associatedtype THasher: StaticHasher
    associatedtype TKey: RuntimeEncodable
    associatedtype TDecodedKey
    
    init(key: TKey, hash: Data)
    init(key: TKey, runtime: any Runtime) throws
    init<D: ScaleCodec.Decoder>(pairFrom decoder: inout D, runtime: any Runtime) throws
    
    var hash: Data { get }
    var decoded: TDecodedKey { get }
}

public protocol TupleStorageKeyPath: ListTuple
    where First: TupleStorageKeyHasherPair, Last: TupleStorageKeyHasherPair
{
    associatedtype TKeys: ListTuple where
        TKeys.First == First.TKey, TKeys.Last == Last.TKey
    associatedtype TDecodedKeys: ListTuple where
        TDecodedKeys.First == First.TDecodedKey, TDecodedKeys.Last == Last.TDecodedKey
    associatedtype THashes: ListTuple & OneTypeTuple<Data> where
        THashes.First == Data, THashes.Last == Data
    
    init(keys: TKeys, runtime: any Runtime) throws
    init<D: ScaleCodec.Decoder>(pairsFrom decoder: inout D, runtime: any Runtime) throws
    
    var keys: TDecodedKeys { get }
    var hashes: THashes { get }
    
    var hash: Data { get }
}

public protocol TupleStorageValidatableKeyPath: TupleStorageKeyPath where
    First.TKey: ValidatableTypeStatic, Last.TKey: ValidatableTypeStatic
{
    static func fillValidatable(path: inout StorageKeyChildKeyTypes)
}

public protocol TupleStorageIdentifiableKeyPath: TupleStorageKeyPath where
    First.TKey: IdentifiableTypeStatic, Last.TKey: IdentifiableTypeStatic
{
    static func fillDefinitions(
        registry: TypeRegistry<TypeDefinition.TypeId>,
        defs: inout StorageKeyTypeKeysInfo
    )
}

public protocol TupleStorageNKeyPath: TupleStorageKeyPath where DroppedFirst: TupleStorageKeyPath {}

public protocol TupleStorageKeyBase<TPath, TValue>: StaticStorageKey
    where TParams == TPath.TKeys.STuple
{
    associatedtype TPath: TupleStorageKeyPath
    var path: TPath { get }
    var keys: TPath.TDecodedKeys.STuple { get }
    var hashes: TPath.THashes.STuple { get }
    init(path: TPath)
}

public extension TupleStorageKeyBase {
    var keys: TPath.TDecodedKeys.STuple { path.keys.tuple }
    var hashes: TPath.THashes.STuple { path.hashes.tuple }
    var pathHash: Data { path.hash }
    
    init(_ params: TParams, runtime: any Runtime) throws {
        try self.init(path: TPath(keys: TPath.TKeys(params), runtime: runtime))
    }
    
    init<D: ScaleCodec.Decoder>(decodingPath decoder: inout D, runtime: any Runtime) throws {
        try self.init(path: TPath(pairsFrom: &decoder, runtime: runtime))
    }
}

public extension TupleStorageKeyBase where
    Self: ComplexStaticFrameType, TPath: TupleStorageValidatableKeyPath,
    ChildTypes == StorageKeyChildTypes, TValue: ValidatableTypeStatic
{
    @inlinable
    static var childTypes: ChildTypes {
        var path = StorageKeyChildKeyTypes()
        path.reserveCapacity(TPath.count)
        TPath.fillValidatable(path: &path)
        return (keys: path, value: TValue.self)
    }
}

public extension TupleStorageKeyBase where
    TPath: TupleStorageIdentifiableKeyPath, TValue: IdentifiableTypeStatic
{
    @inlinable
    static func definition(in registry: TypeRegistry<TypeDefinition.TypeId>) -> FrameTypeDefinition {
        var defs = StorageKeyTypeKeysInfo()
        defs.reserveCapacity(TPath.count)
        TPath.fillDefinitions(registry: registry, defs: &defs)
        return .storage(keys: defs, value: registry.def(TValue.self))
    }
}

public protocol TupleStorageKey<TPath, TValue>: TupleStorageKeyBase, IterableStorageKey
    where TIterator == TupleStorageKeyIterator<Self> {}

public extension TupleStorageKeyHasherPair {
    init(key: TKey, runtime: any Runtime) throws {
        let encoded = try runtime.encode(value: key)
        let hash = THasher.instance.hash(data: encoded)
        self.init(key: key, hash: hash)
    }
}

public struct FKH<K: RuntimeEncodable, H: StaticFixedHasher>: TupleStorageKeyHasherPair {
    public typealias THasher = H
    public typealias TKey = K
    public typealias TDecodedKey = Void
    
    public let hash: Data
    public let key: K?
    public var decoded: Void { () }
    
    public init(key: TKey, hash: Data) {
        self.key = key
        self.hash = hash
    }
    
    public init<D: ScaleCodec.Decoder>(pairFrom decoder: inout D, runtime: Runtime) throws {
        self.key = nil
        self.hash = try decoder.decode(.fixed(UInt(H.bitWidth / 8)))
    }
}
extension FKH: Equatable where K: Equatable, H: Equatable {}

public struct CKH<K: RuntimeCodable, H: StaticConcatHasher>: TupleStorageKeyHasherPair {
    public typealias THasher = H
    public typealias TKey = K
    public typealias TDecodedKey = K
    
    public let hash: Data
    public let key: K
    public var decoded: K { key }
    
    public init(key: TKey, hash: Data) {
        self.key = key
        self.hash = hash
    }
    
    public init<D: ScaleCodec.Decoder>(pairFrom decoder: inout D, runtime: Runtime) throws {
        let hash: Data = try decoder.decode(.fixed(UInt(H.instance.hashPartByteLength)))
        var skippable = decoder.skippable()
        let lengthBefore = skippable.length
        self.key = try K(from: &skippable, runtime: runtime)
        let keyData = try decoder.decode(.fixed(UInt(lengthBefore - skippable.length)))
        self.hash = hash + keyData
    }
}
extension CKH: Equatable where K: Equatable, H: Equatable {}

public struct TupleStorageKeyIterator<Key: TupleStorageKeyBase> {
    public struct SubIterator<Prev: StorageKeyIterator, Path: TupleStorageKeyPath> {
        public let previous: Prev
        public let key: Path.First
        
        public init(prev: Prev, key: Path.First) {
            self.previous = prev
            self.key = key
        }
    }
    
    public init() {}
}

extension TupleStorageKeyIterator: StorageKeyRootIterator {
    public typealias TParam = Void
    public typealias TKey = Key
    public init(base: Void) { self.init() }
}

extension TupleStorageKeyIterator: IterableStorageKeyIterator
    where Key.TPath: TupleStorageNKeyPath
{
    public typealias TIterator = SubIterator<Self, Key.TPath>
    
    public func next(param: TIterator.TParam, runtime: Runtime) throws -> TIterator {
        try TIterator(prev: self, key: Key.TPath.First(key: param, runtime: runtime))
    }
}

extension TupleStorageKeyIterator.SubIterator: StorageKeyIterator {
    public typealias TParam = Path.TKeys.First
    public typealias TKey = Key
    
    public var hash: Data { previous.hash + key.hash }
}

extension TupleStorageKeyIterator.SubIterator: IterableStorageKeyIterator
    where Path: TupleStorageNKeyPath
{
    public typealias TIterator =
        TupleStorageKeyIterator.SubIterator<Self, Path.DroppedFirst>
    
    public func next(param: TIterator.TParam, runtime: Runtime) throws -> TIterator {
        try TIterator(prev: self, key: Path.DroppedFirst.First(key: param, runtime: runtime))
    }
}
