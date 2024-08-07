import "NonFungibleToken"

/// Contract interface enabling FlowEVMBridge to mint NFTs from implementing bridge contracts.
///
access(all)
contract interface IEVMBridgeNFTMinter {

    access(all) event Minted(type: String, id: UInt64, uuid: UInt64, evmID: UInt256, tokenURI: String, minter: Address)
    access(all) event TokenURIUpdated(evmID: UInt256, newURI: String, updater: Address)

    /// Account-only method to mint an NFT
    ///
    access(account)
    fun mintNFT(id: UInt256, tokenURI: String): @{NonFungibleToken.NFT} {
        post {
            emit Minted(
                type: result.getType().identifier,
                id: result.id,
                uuid: result.uuid,
                evmID: id,
                tokenURI: tokenURI,
                minter: self.account.address
            )
        }
    }

    /// Allows the bridge to update the URI of bridged NFTs. This assumes that the EVM-defining project may contain
    /// logic (onchain or offchain) which updates NFT metadata in the source ERC721 contract. On bridging, the URI can
    /// then be updated in this contract to reflect the source ERC721 contract's metadata.
    ///
    access(account)
    fun updateTokenURI(evmID: UInt256, newURI: String) {
        post {
            emit TokenURIUpdated(evmID: evmID, newURI: newURI, updater: self.account.address)
        }
    }
}
