import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridge"

/// Resolves the view for the requested locked NFT or nil if the NFT is not locked
///
access(all) fun main(nftTypeIdentifier: String, id: UInt64, viewIdentifier: String): AnyStruct? {
    let nftType: Type = CompositeType(nftTypeIdentifier) ?? panic("Malformed nft type identifier")

    if let nft: &{NonFungibleToken.NFT} = FlowEVMBridgeNFTEscrow.borrowLockedNFT(type: nftType, id: id) {
        let view: Type = CompositeType(viewIdentifier) ?? panic("Malformed view type identifier")
        return nft.resolveView(view)
    }
    return nil
}
