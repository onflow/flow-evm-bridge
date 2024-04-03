import "FungibleToken"

/// Contract interface enabling FlowEVMBridge to mint NFTs
///
access(all)
contract interface IEVMBridgeTokenMinter {

    /// Account-only method to mint an NFT
    ///
    access(account)
    fun mintTokens(amount: UFix64): @{FungibleToken.Vault} {
        post {
            result.balance == amount: "Result does not contained specified amount"
        }
    }
}
