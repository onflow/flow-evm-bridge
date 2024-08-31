import "NonFungibleToken"

import "FlowEVMBridgeTokenEscrow"
import "FlowEVMBridge"

/// Returns the views supported by an escrowed FungibleToken Vault or nil if there is no Vault of the given type locked
/// in escrow
///
/// @param vaultTypeIdentifier: The type identifier of the NFT
///
/// @return The metadata view types supported by the escrowed FT Vault or nil if there is not Vault locked in escrow
///
access(all) fun main(vaultTypeIdentifier: String, id: UInt64): [Type]? {
    let type = CompositeType(vaultTypeIdentifier) ?? panic("Malformed Vault type identifier=".concat(vaultTypeIdentifier))
    return FlowEVMBridgeTokenEscrow.getViews(tokenType: type)
}
