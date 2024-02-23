import "NonFungibleToken"

access(all) contract interface IEVMBridgeNFTMinter {

    access(account)
    fun mintNFT(id: UInt256, tokenURI: String): @{NonFungibleToken.NFT}
}