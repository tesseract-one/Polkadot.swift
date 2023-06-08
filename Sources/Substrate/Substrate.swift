//
//  Substrate.swift
//
//
//  Created by Yehor Popovych on 1/11/21.
//

import Foundation
import JsonRPC

public protocol SomeSubstrate<RC>: AnyObject {
    associatedtype RC: RuntimeConfig
    associatedtype CL: SystemApiClient where CL.C == RC
    
    // Dependencies
    var client: CL { get }
    var runtime: ExtendedRuntime<RC> { get }
    var signer: Optional<Signer> { get set }
    
    // API objects
    var rpc: RpcApiRegistry<Self> { get }
    var call: RuntimeApiRegistry<Self> { get }
    var query: StorageApiRegistry<Self> { get }
//    var consts: SubstrateConstantApiRegistry<Self> { get }
    var tx: ExtrinsicApiRegistry<Self> { get }
}

public final class Substrate<RC: RuntimeConfig, CL: SystemApiClient>: SomeSubstrate where CL.C == RC {
    public typealias RC = RC
    public typealias CL = CL
    
    public private(set) var client: CL
    public let runtime: ExtendedRuntime<RC>
    public var signer: Signer?
    
    public let rpc: RpcApiRegistry<Substrate<RC, CL>>
    public let call: RuntimeApiRegistry<Substrate<RC, CL>>
    public let tx: ExtrinsicApiRegistry<Substrate<RC, CL>>
    public let query: StorageApiRegistry<Substrate<RC, CL>>
    
    public init(client: CL, runtime: ExtendedRuntime<RC>, signer: Signer? = nil) throws {
        self.signer = signer
        self.client = client
        self.runtime = runtime
        
        // Set runtime for JSON decoders
        try self.client.setRuntime(runtime: runtime)
        
        // Create registries
        self.rpc = RpcApiRegistry()
        self.tx = ExtrinsicApiRegistry()
        self.call = RuntimeApiRegistry()
        self.query = StorageApiRegistry()
        
        // Init runtime
        try runtime.setSubstrate(substrate: self)
        
        // Init registries
        rpc.setSubstrate(substrate: self)
        tx.setSubstrate(substrate: self)
        call.setSubstrate(substrate: self)
        query.setSubstrate(substrate: self)
    }
    
    public convenience init(client: CL, config: RC, signer: Signer? = nil,
                            at hash: RC.THasher.THash? = nil) async throws {
        // Obtain initial data
        let runtimeVersion = try await client.runtimeVersion(at: hash)
        let properties = try await client.systemProperties()
        let genesisHash = try await client.block(hash: 0)!
        let metadata = try await client.metadata(at: hash)
        let runtime = try ExtendedRuntime(config: config,
                                          metadata: metadata,
                                          metadataHash: hash,
                                          genesisHash: genesisHash,
                                          version: runtimeVersion,
                                          properties: properties)
        try self.init(client: client, runtime: runtime, signer: signer)
    }
    
    public convenience init<CCL: CallableClient & RuntimeHolder>(
        client: CCL, config: RC, signer: Signer? = nil, at hash: RC.THasher.THash? = nil
    ) async throws where CL == RpcSystemApiClient<RC, CCL> {
        let systemClient = RpcSystemApiClient<RC, CCL>(client: client)
        try await self.init(client: systemClient, config: config, signer: signer, at: hash)
    }
}
