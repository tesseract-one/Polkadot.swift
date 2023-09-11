//
//  Events.swift
//  
//
//  Created by Yehor Popovych on 08/06/2023.
//

import Foundation
import ScaleCodec

public protocol SomeBlockEvents: RuntimeLazyDynamicDecodable, ValidatableType, Default {
    associatedtype ER: SomeEventRecord
    var events: [ER] { get }
    func events(extrinsic index: UInt32) -> [ER]
}

public extension SomeBlockEvents {
    func has(event: String, pallet: String) -> Bool {
        events.first {
            $0.header.name == event && $0.header.pallet == pallet
        } != nil
    }
    
    func has(event: String, pallet: String, extrinsic index: UInt32) -> Bool {
        events(extrinsic: index).first {
            $0.header.name == event && $0.header.pallet == pallet
        } != nil
    }
    
    func has<E: PalletEvent>(_ type: E.Type) -> Bool {
        has(event: E.name, pallet: E.pallet)
    }
    
    func has<E: PalletEvent>(_ type: E.Type, extrinsic index: UInt32) -> Bool {
        has(event: E.name, pallet: E.pallet, extrinsic: index)
    }
    
    func all(records event: String, pallet: String) -> [ER] {
        events.filter{
            $0.header.name == event && $0.header.pallet == pallet
        }
    }
    
    func all(records event: String, pallet: String, extrinsic index: UInt32) -> [ER] {
        events(extrinsic: index).filter{
            $0.header.name == event && $0.header.pallet == pallet
        }
    }
    
    func all<E: PalletEvent>(records type: E.Type) -> [ER] {
        all(records: E.name, pallet: E.pallet)
    }
    
    func all<E: PalletEvent>(records type: E.Type, extrinsic index: UInt32) -> [ER] {
        all(records: E.name, pallet: E.pallet, extrinsic: index)
    }
    
    func all(events event: String, pallet: String) throws -> [AnyEvent] {
        try all(records: event, pallet: pallet).map { try $0.any }
    }
    
    func all(events event: String, pallet: String, extrinsic index: UInt32) throws -> [AnyEvent] {
        try all(records: event, pallet: pallet, extrinsic: index).map { try $0.any }
    }
    
    func all<E: PalletEvent>(events type: E.Type) throws -> [E] {
        try all(records: E.name, pallet: E.pallet).map { try $0.typed(type) }
    }
    
    func all<E: PalletEvent>(events type: E.Type, extrinsic index: UInt32) throws -> [E] {
        try all(records: E.name, pallet: E.pallet, extrinsic: index).map { try $0.typed(type) }
    }
    
    func first(record event: String, pallet: String) -> ER? {
        events.first {
            $0.header.name == event && $0.header.pallet == pallet
        }
    }
    
    func first(record event: String, pallet: String, extrinsic index: UInt32) -> ER? {
        events(extrinsic: index).first {
            $0.header.name == event && $0.header.pallet == pallet
        }
    }
    
    func first<E: PalletEvent>(record type: E.Type) -> ER? {
        first(record: E.name, pallet: E.pallet)
    }
    
    func first<E: PalletEvent>(record type: E.Type, extrinsic index: UInt32) -> ER? {
        first(record: E.name, pallet: E.pallet, extrinsic: index)
    }
    
    func first(event name: String, pallet: String) throws -> AnyEvent? {
        try first(record: name, pallet: pallet).map{try $0.any}
    }
    
    func first(event name: String, pallet: String, extrinsic index: UInt32) throws -> AnyEvent? {
        try first(record: name, pallet: pallet, extrinsic: index).map{try $0.any}
    }
    
    func first<E: PalletEvent>(event type: E.Type) throws -> E? {
        try first(record: type).map{try $0.typed(type)}
    }
    
    func first<E: PalletEvent>(event type: E.Type, extrinsic index: UInt32) throws -> E? {
        try first(record: type, extrinsic: index).map{try $0.typed(type)}
    }
    
    func last(record event: String, pallet: String) -> ER? {
        events.last {
            $0.header.name == event && $0.header.pallet == pallet
        }
    }
    
    func last(record event: String, pallet: String, extrinsic index: UInt32) -> ER? {
        events(extrinsic: index).last {
            $0.header.name == event && $0.header.pallet == pallet
        }
    }
    
    func last<E: PalletEvent>(record type: E.Type) -> ER? {
        last(record: E.name, pallet: E.pallet)
    }
    
    func last<E: PalletEvent>(record type: E.Type, extrinsic index: UInt32) -> ER? {
        last(record: E.name, pallet: E.pallet, extrinsic: index)
    }
    
    func last(event name: String, pallet: String) throws -> AnyEvent? {
        try last(record: name, pallet: pallet).map{try $0.any}
    }
    
    func last(event name: String, pallet: String, extrinsic index: UInt32) throws -> AnyEvent? {
        try last(record: name, pallet: pallet, extrinsic: index).map{try $0.any}
    }
    
    func last<E: PalletEvent>(event type: E.Type) throws -> E? {
        try last(record: type).map{try $0.typed(type)}
    }
    
    func last<E: PalletEvent>(event type: E.Type, extrinsic index: UInt32) throws -> E? {
        try last(record: type, extrinsic: index).map{try $0.typed(type)}
    }
    
    func parsed() throws -> [AnyEvent] {
        try events.map { try $0.any }
    }
    
    func parsed(extrinsic index: UInt32) throws -> [AnyEvent] {
        try events(extrinsic: index).map { try $0.any }
    }
}
