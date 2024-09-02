import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeTokenEscrow"
import "FlowEVMBridgeUtils"

/// Resolves the view for the requested locked Vault or nil if the Vault is not locked in escrow
/// NOTE: This functionality is not available via the escrow contract as `resolveView` is not a `view` method, but the
///     escrow contract does provide the necessary functionality to resolve the view from the context of a script
///
/// @param bridgeAddress: The address of the bridge contract (included as the VM bridge address varies across networks)
/// @param vaultTypeIdentifier: The identifier of the Vault type
/// @param viewIdentifier: The identifier of the view to resolve
///
/// @return The resolved view if the Vault is escrowed & the view is resolved by it or nil if the Vault is not locked
///
access(all) fun main(bridgeAddress: Address, vaultTypeIdentifier: String, viewIdentifier: String): AnyStruct? {
    // Construct runtime types from provided identifiers
    let vaultType: Type = CompositeType(vaultTypeIdentifier) ?? panic("Malformed vault type identifier=".concat(vaultTypeIdentifier))
    let view: Type = CompositeType(viewIdentifier) ?? panic("Malformed view type identifier=".concat(viewIdentifier))

    // Derive the Locker path for the given Vault type
    let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: vaultType)
        ?? panic("Problem deriving Locker path for NFT type identifier=".concat(vaultTypeIdentifier))

    // Borrow the locker from the bridge account's storage & return the requested view if the locker exists
    if let locker = getAuthAccount<auth(BorrowValue) &Account>(bridgeAddress).storage.borrow<&FlowEVMBridgeTokenEscrow.Locker>(
        from: lockerPath
    ) {
        return locker.resolveView(view)
    }

    return nil
}
