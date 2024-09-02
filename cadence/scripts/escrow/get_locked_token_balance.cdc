import "FlowEVMBridgeTokenEscrow"

/// Returns the balance of a given FungibleToken Vault type locked in escrow or nil if a vault of the given type is not
/// locked in escrow
///
/// @param vaultTypeIdentifier: The type identifier of the FungibleToken Vault
///
access(all) fun main(vaultTypeIdentifier: String): UFix64? {
    let tokenType = CompositeType(vaultTypeIdentifier) ?? panic("Malformed Vault type identifier=".concat(vaultTypeIdentifier))
    return FlowEVMBridgeTokenEscrow.getLockedTokenBalance(tokenType: tokenType)
}
