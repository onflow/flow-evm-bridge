import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeTokenEscrow"
import "FlowEVMBridge"

/// Resolves the view for the requested locked Vault or nil if the Vault is not locked in escrow
///
/// @param vaultTypeIdentifier: The identifier of the Vault type
/// @param viewIdentifier: The identifier of the view to resolve
///
/// @return The resolved view if the Vault is escrowed & the view is resolved by it or nil if the Vault is not locked
///
access(all) fun main(vaultTypeIdentifier: String, viewIdentifier: String): AnyStruct? {
    let vaultType: Type = CompositeType(vaultTypeIdentifier) ?? panic("Malformed vault type identifier=".concat(vaultTypeIdentifier))
    let view: Type = CompositeType(viewIdentifier) ?? panic("Malformed view type identifier=".concat(viewIdentifier))

    return FlowEVMBridgeTokenEscrow.resolveLockedTokenView(tokenType: vaultType, viewType: view)
}
