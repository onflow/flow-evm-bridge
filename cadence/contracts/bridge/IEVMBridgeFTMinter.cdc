import "FungibleToken"

/// Contract interface enabling FlowEVMBridge to mint NFTs
///
access(all)
contract interface IEVMBridgeFTMinter {

    /// Account-only method to mint an NFT
    ///
    access(account)
    fun mintFT(amount: UFix64): @{FungibleToken.Vault}
}
