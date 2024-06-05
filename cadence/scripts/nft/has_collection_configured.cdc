import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

import "FlowEVMBridgeUtils"

/// Returns true if the recipient has Collection configured for the provided NFT contract
///
/// @param nftIdentifier The type identifier of the NFT Collection to check for
/// @param recipient The address of the recipient
///
/// @returns true if the recipient has Collection configured for the provided NFT contract, false if not. Reverts if the
///     provided contract cannot be accessed or does not have default Collection storage information.
///
access(all)
fun main(nftIdentifier: String, recipient: Address): Bool {
    let nftType = CompositeType(nftIdentifier) ?? panic("Invalid nft identifier: ".concat(nftIdentifier))
    let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: nftType)
        ?? panic("Could not find contract address for nft: ".concat(nftIdentifier))
    let contractName = FlowEVMBridgeUtils.getContractName(fromType: nftType)
        ?? panic("Could not find contract name for nft: ".concat(nftIdentifier))
    let nftContract = getAccount(contractAddress).contracts.borrow<&{NonFungibleToken}>(name: contractName)
        ?? panic("No such contract found")
    let collectionData = nftContract.resolveContractView(
            resourceType: nftType,
            viewType: Type<MetadataViews.NFTCollectionData>()
        ) as! MetadataViews.NFTCollectionData?
        ?? panic("FungibleToken does not provide default Collection data")
    return getAccount(recipient).capabilities.exists(collectionData.publicPath)
}
