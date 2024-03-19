import "NonFungibleToken"

/// Contract interface enabling FlowEVMBridge to mint NFTs
///
access(all)
contract interface IEVMBridgeNFTMinter {

    /// Account-only method to mint an NFT
    ///
    access(account)
    fun mintNFT(id: UInt256, tokenURI: String): @{NonFungibleToken.NFT}

    /// Allows the bridge to update the URI of bridged NFTs. This assumes that the EVM-defining project may contain
    /// logic (onchain or offchain) which updates NFT metadata in the source ERC721 contract. On bridging, the URI can
    /// then be updated in this contract to reflect the source ERC721 contract's metadata.
    ///
    access(account)
    fun updateTokenURI(evmID: UInt256, newURI: String)
}
