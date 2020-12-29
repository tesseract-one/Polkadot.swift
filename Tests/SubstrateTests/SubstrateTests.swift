//
//  File.swift
//  
//
//  Created by Yehor Popovych on 12/25/20.
//

import XCTest
import ScaleCodec
@testable import Substrate

final class SubstrateTests: XCTestCase {
    func testMetadataParsoing() {
        let disconnected = expectation(description: "Disconnected")
        let client = HttpRpcClient(url: URL(string: "https://rpc.polkadot.io")!)
        
        let parse = { (data: Data) in
            let metadata: RuntimeVersionedMetadata = try! SCALE.default.decode(from: data)
            print("Metadata", metadata)
        }
        
        client.call(method: "state_getMetadata", params: Array<Int>()) { (res: Result<HexData, RpcClientError>) in
            switch res {
            case .success(let hd): parse(hd.data)
            case .failure(let err): print("Erorr", err)
            }
            disconnected.fulfill()
        }
        
        wait(for: [disconnected], timeout: 30.0)
    }
}

