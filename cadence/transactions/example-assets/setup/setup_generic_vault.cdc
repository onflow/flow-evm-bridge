import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "FungibleTokenMetadataViews"

import "FlowEVMBridgeUtils"

transaction(vaultIdentifier: String) {
    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        // Gather identifying information about the Vault and its defining contract
        let vaultType = CompositeType(vaultIdentifier) ?? panic("Invalid Vault identifier: ".concat(vaultIdentifier))
        let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: vaultType)
            ?? panic("Could not derive contract address from identifier: ".concat(vaultIdentifier))
        let contractName = FlowEVMBridgeUtils.getContractName(fromType: vaultType)
            ?? panic("Could not derive contract name from identifier: ".concat(vaultIdentifier))
        // Borrow the contract and resolve its Vault data
        let ftContract = getAccount(contractAddress).contracts.borrow<&{FungibleToken}>(name: contractName)
            ?? panic("No such FungibleToken contract found")
        let data = ftContract.resolveContractView(
                resourceType: vaultType,
                viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
            ) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not resolve collection data for Vault type: ".concat(vaultIdentifier))

        // Create a new collection and save it to signer's storage at the collection's default storage path
        signer.storage.save(<-data.createEmptyVault(), to: data.storagePath)

        // Issue a public Collection capability and publish it to the collection's default public path
        signer.capabilities.unpublish(data.receiverPath)
        let receiverCap = signer.capabilities.storage.issue<&{FungibleToken.Vault}>(data.storagePath)
        signer.capabilities.publish(receiverCap, at: data.receiverPath)
    }
}
