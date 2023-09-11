//
//  Address.swift
//  
//
//  Created by Yehor Popovych on 21.04.2023.
//

import Foundation
import ScaleCodec

public protocol Address<TAccountId>: RuntimeLazyDynamicCodable,
                                     ValueRepresentable, ValidatableType {
    associatedtype TAccountId: AccountId
    
    init(accountId: TAccountId,
         runtime: any Runtime,
         type: TypeDefinition.Lazy) throws
}

public protocol StaticAddress<TAccountId>: Address, RuntimeCodable {
    init(accountId: TAccountId, runtime: any Runtime) throws
}

public extension StaticAddress {
    @inlinable
    init(accountId: TAccountId,
         runtime: any Runtime,
         type: TypeDefinition.Lazy) throws
    {
        try self.init(accountId: accountId, runtime: runtime)
    }
}
