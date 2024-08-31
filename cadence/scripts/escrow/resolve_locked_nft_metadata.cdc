import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridge"

/// Resolves the view for the requested locked NFT or nil if the NFT is not locked
///
/// @param nftTypeIdentifier: The identifier of the NFT type
/// @param id: The ERC721 id of the escrowed NFT
/// @param viewIdentifier: The identifier of the view to resolve
///
/// @return The resolved view if the NFT is escrowed & the view is resolved by it or nil if the NFT is not locked
///
access(all) fun main(nftTypeIdentifier: String, id: UInt256, viewIdentifier: String): AnyStruct? {
    let nftType: Type = CompositeType(nftTypeIdentifier) ?? panic("Malformed NFT type identifier=".concat(nftTypeIdentifier))
    let view: Type = CompositeType(viewIdentifier) ?? panic("Malformed view type identifier=".concat(viewIdentifier))

    return FlowEVMBridgeNFTEscrow.resolveLockedNFTView(nftType: nftType, id: id, viewType: view)
}
