import "NonFungibleToken"

import "IEVMBridgeNFTLocker"
import "FlowEVMBridge"

/// Returns true if the NFT is locked and false otherwise.
///
access(all) fun main(nftTypeIdentifier: String, id: UInt64): Bool {
    let type = CompositeType(nftTypeIdentifier) ?? panic("Malformed type identifier")
    if let locker = FlowEVMBridge.borrowLockerContract(forType: type) {
        return locker.borrowLockedNFT(id: id) != nil
    }
    return false
}
