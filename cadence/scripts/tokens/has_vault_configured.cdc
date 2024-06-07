import "FungibleToken"
import "FungibleTokenMetadataViews"
import "ViewResolver"

import "FlowEVMBridgeUtils"

/// Returns true if the recipient has Vault configured for the provided FungibleToken contract
///
/// @param vaultIdentifier The type identifier of the Vault to check for
/// @param recipient The address of the recipient
///
/// @returns true if the recipient has Vault configured for the provided FungibleToken contract, false if not. Reverts
///     if the provided contract cannot be accessed or does not have default Vault storage information.
///
access(all)
fun main(vaultIdentifier: String, recipient: Address): Bool {
    let vaultType = CompositeType(vaultIdentifier) ?? panic("Invalid vault identifier: ".concat(vaultIdentifier))
    let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: vaultType)
        ?? panic("Could not find contract address for vault: ".concat(vaultIdentifier))
    let contractName = FlowEVMBridgeUtils.getContractName(fromType: vaultType)
        ?? panic("Could not find contract name for vault: ".concat(vaultIdentifier))
    let tokenContract = getAccount(contractAddress).contracts.borrow<&{FungibleToken}>(name: contractName)
        ?? panic("No such contract found")
    let vaultData = tokenContract.resolveContractView(
            resourceType: vaultType,
            viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
        ) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("FungibleToken does not provide default Vault data")
    return getAccount(recipient).capabilities.exists(vaultData.receiverPath)
}
