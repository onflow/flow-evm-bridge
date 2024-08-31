import "NonFungibleToken"

import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridge"

/// Returns the views supported by an escrowed NFT or nil if the NFT is not locked in escrow
///
/// @param nftTypeIdentifier: The type identifier of the NFT
/// @param id: The ID of the NFT
///
/// @return The metadata view types supported by the escrowed NFT or nil if the NFT is not locked in escrow
///
access(all) fun main(nftTypeIdentifier: String, id: UInt64): [Type]? {
    let type = CompositeType(nftTypeIdentifier) ?? panic("Malformed NFT type identifier=".concat(nftTypeIdentifier))
    return FlowEVMBridgeNFTEscrow.getViews(nftType: type, id: id)
}
