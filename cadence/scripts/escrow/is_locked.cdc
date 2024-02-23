import "NonFungibleToken"

import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridge"

/// Returns true if the NFT is locked and false otherwise.
///
access(all) fun main(nftTypeIdentifier: String, id: UInt64): Bool {
    let type = CompositeType(nftTypeIdentifier) ?? panic("Malformed type identifier")
    return FlowEVMBridgeNFTEscrow.isLocked(type: type, id: id)
}
