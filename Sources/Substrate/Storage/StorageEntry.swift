//
//  StorageEntry.swift
//  
//
//  Created by Yehor Popovych on 09/06/2023.
//

import Foundation

public struct StorageEntry<R: RootApi, Key: StorageKey> {
    public let api: R
    public let params: Key.TBaseParams
   
    public init(api: R, params: Key.TBaseParams) throws {
        try Key.validate(base: params, runtime: api.runtime)
        self.params = params
        self.api = api
    }
    
    public func key(_ params: Key.TParams) throws -> Key {
        try Key(base: self.params, params: params, runtime: api.runtime)
    }
    
    public func size(
        key: Key,
        at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) async throws -> UInt64 {
        try await api.client.storage(size: key, at: hash ?? api.hash, runtime: api.runtime)
    }
    
    public func size(
        _ params: Key.TParams,
        at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) async throws -> UInt64 {
        try await size(key: key(params), at: hash ?? api.hash)
    }
    
    public func value(
        key: Key,
        at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) async throws -> Key.TValue? {
        try await api.client.storage(value: key, at: hash ?? api.hash, runtime: api.runtime)
    }
    
    public func value(
        _ params: Key.TParams,
        at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) async throws -> Key.TValue? {
        try await value(key: key(params), at: hash ?? api.hash)
    }
    
    public func defaultValue() throws -> Key.TValue {
        try Key.defaultValue(base: params, runtime: api.runtime)
    }
    
    public func valueOrDefault(
        key: Key,
        at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) async throws -> Key.TValue {
        if let value = try await value(key: key, at: hash ?? api.hash) {
            return value
        }
        return try defaultValue()
    }
    
    public func valueOrDefault(
        _ params: Key.TParams,
        at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) async throws -> Key.TValue {
        try await valueOrDefault(key: key(params), at: hash)
    }
}

public extension StorageEntry {
    struct Iterator<Iter: StorageKeyIterator> where Iter.TKey == Key {
        public let api: R
        public let iterator: Iter
        
        public init(api: R, iterator: Iter) {
            self.api = api
            self.iterator = iterator
        }
        
        public func keys(
            page: Int = 20, at hash: R.RC.TBlock.THeader.THasher.THash? = nil
        ) -> AsyncThrowingStream<Iter.TKey, Error> {
            var buffer: [Iter.TKey] = []
            buffer.reserveCapacity(page)
            var lastKey: Iter.TKey? = nil
            var atHash: R.RC.TBlock.THeader.THasher.THash? = hash ?? api.hash
            return AsyncThrowingStream<Iter.TKey, Error> {
                if atHash == nil {
                    atHash = try await api.client.block(hash: nil, runtime: api.runtime)!
                }
                if buffer.count > 0 { return buffer.removeFirst() }
                let new = try await api.client.storage(keys: iterator,
                                                       count: page,
                                                       startKey: lastKey,
                                                       at: atHash,
                                                       runtime: api.runtime)
                lastKey = new.last
                guard new.count > 0 else { return nil }
                buffer.append(contentsOf: new)
                return buffer.removeFirst()
            }
        }
        
        public func entries(
            page: Int = 20, at hash: R.RC.TBlock.THeader.THasher.THash? = nil
        ) -> AsyncThrowingStream<(Iter.TKey, Iter.TKey.TValue), Error> {
            var buffer: [(Iter.TKey, Iter.TKey.TValue)] = []
            buffer.reserveCapacity(page)
            var lastKey: Iter.TKey? = nil
            var atHash: R.RC.TBlock.THeader.THasher.THash? = hash ?? api.hash
            return AsyncThrowingStream<(Iter.TKey, Iter.TKey.TValue), Error> {
                if atHash == nil {
                    atHash = try await api.client.block(hash: nil, runtime: api.runtime)!
                }
                if buffer.count > 0 { return buffer.removeFirst() }
                var finished: Bool = false
                repeat {
                    let new = try await api.client.storage(keys: iterator,
                                                           count: page,
                                                           startKey: lastKey,
                                                           at: atHash,
                                                           runtime: api.runtime)
                    lastKey = new.last
                    guard new.count > 0 else { return nil }
                    let changes = try await api.client.storage(changes: new,
                                                               at: atHash,
                                                               runtime: api.runtime)
                    let filtered = changes.flatMap { chSet in
                        chSet.changes.compactMap { $0.value != nil ? ($0.key, $0.value!) : nil }
                    }
                    if filtered.count > 0 {
                        buffer.append(contentsOf: filtered)
                        finished = true
                    }
                } while (!finished)
                return buffer.removeFirst()
            }
        }
    }
}

public extension StorageEntry where Key: IterableStorageKey {
    var iterator: Key.TIterator { Key.TIterator(base: params) }
    
    func entries(
        page: Int = 20, at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) -> AsyncThrowingStream<(Key, Key.TValue), Error> {
        Iterator(api: api, iterator: iterator).entries(page: page, at: hash ?? api.hash)
    }
    
    func keys(
        page: Int = 20, at hash: R.RC.TBlock.THeader.THasher.THash? = nil
    ) -> AsyncThrowingStream<Key, Error> {
        Iterator(api: api, iterator: iterator).keys(page: page, at: hash ?? api.hash)
    }
}

public extension StorageEntry where Key: IterableStorageKey, Key.TIterator: IterableStorageKeyIterator {
    func filter(
        _ param: Key.TIterator.TIterator.TParam
    ) throws -> Iterator<Key.TIterator.TIterator> {
        try Iterator(api: api,
                     iterator: iterator.next(param: param, runtime: api.runtime))
    }
}

public extension StorageEntry where Key: DynamicStorageKey {
    func size(at hash: R.RC.TBlock.THeader.THasher.THash? = nil) async throws -> UInt64 {
        try await size(
            key: Key(base: (params.name, params.pallet), params: [], runtime: api.runtime),
            at: hash ?? api.hash
        )
    }
    
    func value(at hash: R.RC.TBlock.THeader.THasher.THash? = nil) async throws -> Key.TValue? {
        try await value(
            key: Key(base: (params.name, params.pallet), params: [], runtime: api.runtime),
            at: hash ?? api.hash
        )
    }
    
    func valueOrDefault(at hash: R.RC.TBlock.THeader.THasher.THash? = nil) async throws -> Key.TValue {
        try await valueOrDefault(
            key: Key(base: (params.name, params.pallet), params: [], runtime: api.runtime),
            at: hash ?? api.hash
        )
    }
    
    func filter(keys: [any ValueRepresentable]) throws -> Iterator<Key.TIterator.TIterator> {
        try Iterator(api: api,
                     iterator: Key.TIterator.TIterator(name: self.params.name,
                                                       pallet: self.params.pallet,
                                                       params: keys,
                                                       runtime: api.runtime))
    }
}

public extension StorageEntry where Key.TParams == Void {
    func size(at hash: R.RC.TBlock.THeader.THasher.THash? = nil) async throws -> UInt64 {
        try await size(key: Key(base: params, params: (), runtime: api.runtime), at: hash ?? api.hash)
    }
    
    func value(at hash: R.RC.TBlock.THeader.THasher.THash? = nil) async throws -> Key.TValue? {
        try await value(key: Key(base: params, params: (), runtime: api.runtime), at: hash ?? api.hash)
    }
    
    func valueOrDefault(at hash: R.RC.TBlock.THeader.THasher.THash? = nil) async throws -> Key.TValue {
        try await valueOrDefault(key: Key(base: params, params: (), runtime: api.runtime), at: hash ?? api.hash)
    }
}

public extension StorageEntry.Iterator where Iter: IterableStorageKeyIterator {
    func filter(
        _ param: Iter.TIterator.TParam
    ) throws -> StorageEntry.Iterator<Iter.TIterator> {
        try StorageEntry.Iterator<_>(api: api,
                                     iterator: iterator.next(param: param,
                                                             runtime: api.runtime))
    }
}

public extension StorageEntry where R.CL: SubscribableClient {
    func watch(keys: [Key]) async throws -> AsyncThrowingStream<(Key, Key.TValue?), Error> {
        try await api.client.subscribe(storage: keys, runtime: api.runtime)
    }
    
    func watch(_ params: Key.TParams) async throws -> AsyncThrowingStream<(Key, Key.TValue?), Error> {
        try await watch(keys: [key(params)])
    }
}

public extension StorageEntry where R.CL: SubscribableClient, Key.TParams == Void {
    func watch() async throws -> AsyncThrowingStream<(Key, Key.TValue?), Error> {
        try await watch(keys: [key(())])
    }
}
