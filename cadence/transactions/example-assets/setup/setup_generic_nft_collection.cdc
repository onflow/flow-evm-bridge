import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeUtils"

/// Configures a Collection according to the shared NonFungibleToken standard and the defaults specified by the NFT's
/// defining contract.
///
/// @param nftIdentifier: The identifier of the NFT to configure.
///
transaction(nftIdentifier: String) {

    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        // Gather identifying information about the NFT and its defining contract
        let nftType = CompositeType(nftIdentifier) ?? panic("Invalid NFT identifier: ".concat(nftIdentifier))
        let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: nftType)
            ?? panic("Could not derive contract address from identifier: ".concat(nftIdentifier))
        let contractName = FlowEVMBridgeUtils.getContractName(fromType: nftType)
            ?? panic("Could not derive contract name from identifier: ".concat(nftIdentifier))
        // Borrow the contract and resolve its collection data
        let nftContract = getAccount(contractAddress).contracts.borrow<&{NonFungibleToken}>(name: contractName)
            ?? panic("No such NFT contract found")
        let data = nftContract.resolveContractView(
                resourceType: nftType,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollection data for NFT type: ".concat(nftIdentifier))

        // Check for collision, returning if the collection already exists or reverting on unexpected collision
        let storedType = signer.storage.type(at: data.storagePath)
        if storedType == nftType {
            return
        } else if storedType != nil {
            panic(
                "Another resource of type "
                .concat(storedType!.identifier)
                .concat(" already exists at the storage path: ")
                .concat(data.storagePath.toString())
            )
        }

        // Create a new collection and save it to signer's storage at the collection's default storage path
        signer.storage.save(<-data.createEmptyCollection(), to: data.storagePath)

        // Issue a public Collection capability and publish it to the collection's default public path
        signer.capabilities.unpublish(data.publicPath)
        let receiverCap = signer.capabilities.storage.issue<&{NonFungibleToken.Collection}>(data.storagePath)
        signer.capabilities.publish(receiverCap, at: data.publicPath)
    }
}
