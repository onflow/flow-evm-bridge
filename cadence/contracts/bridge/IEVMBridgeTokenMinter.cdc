import "FungibleToken"

/// Contract interface enabling FlowEVMBridge to mint fungible tokens from implementing bridge contracts.
///
access(all)
contract interface IEVMBridgeTokenMinter {

    /// Emitted whenever tokens are minted, identifying the type, amount, and minter
    access(all) event Minted(type: Type, amount: UFix64, minter: Address)

    /// Account-only method to mint a fungible token of the specified amount.
    ///
    access(account)
    fun mintTokens(amount: UFix64): @{FungibleToken.Vault} {
        post {
            result.balance == amount: "Result does not contained specified amount"
            emit Minted(type: result.getType(), amount: amount, minter: self.account.address)
        }
    }
}
