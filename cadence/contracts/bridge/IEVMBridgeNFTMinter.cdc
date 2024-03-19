import "NonFungibleToken"

/// Contract interface enabling FlowEVMBridge to mint NFTs
///
access(all)
contract interface IEVMBridgeNFTMinter {

    /// Account-only method to mint an NFT
    ///
    access(account)
    fun mintNFT(id: UInt256, tokenURI: String): @{NonFungibleToken.NFT}
}
