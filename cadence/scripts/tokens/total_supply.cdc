import "FungibleToken"
import "FungibleTokenMetadataViews"

/// Returns the total supply of the tokens defining the Vault at the given address
///
/// @param contractAddress: The address of the token contract
/// @param contractName: The name of the token contract
/// @param vaultTypeIdentifier: The identifier of the vault's Type
///
/// @returns The total supply of tokens in circulation of the specified vault type if the FT contract implements the
///         `FungibleTokenMetadata.TotalSupply` view or nil. A nil value may indicate that either the specified vault
///         type does not exist or the FT contract does not implement the `FungibleTokenMetadata.TotalSupply` view.
///
access(all) fun main(contractAddress: Address, contractName: String, vaultTypeIdentifier: String): UFix64? {
    let ftContract = getAccount(contractAddress).contracts.borrow<&{FungibleToken}>(name: contractName)
    if ftContract == nil {
        return nil
    }
    let vaultType = CompositeType(vaultTypeIdentifier)
    if vaultType == nil {
        return nil
    }

    if let totalSupplyView = ftContract!.resolveContractView(
            resourceType: vaultType!, 
            viewType: Type<FungibleTokenMetadataViews.TotalSupply>()
        ) as! FungibleTokenMetadataViews.TotalSupply? {
        return totalSupplyView.supply
    }
    return nil
}
