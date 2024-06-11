import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeUtils"

/// A struct that contains information about an NFT collection.
///
access(all)
struct CollectionInfo {
    access(all) let name: String
    access(all) let symbol: String?
    access(all) let description: String
    access(all) let squareImage: String
    access(all) let banner: String
    access(all) let contractURI: String?
    access(all) let collectionStoragePath: StoragePath
    access(all) let receiverPublicPath: PublicPath
    access(all) let collectionLength: Int

    init(
        name: String,
        symbol: String?,
        description: String,
        squareImage: String,
        banner: String,
        contractURI: String?,
        collectionStoragePath: StoragePath,
        receiverPublicPath: PublicPath,
        collectionLength: Int
    ) {
        self.name = name
        self.symbol = symbol
        self.description = description
        self.squareImage = squareImage
        self.banner = banner
        self.contractURI = contractURI
        self.collectionStoragePath = collectionStoragePath
        self.receiverPublicPath = receiverPublicPath
        self.collectionLength = collectionLength
    }
}

/// Returns information about the given NFT collection.
///
access(all)
fun getInfoFromCollection(_ collection: &{NonFungibleToken.Collection}): CollectionInfo? {
    let collectionType = collection.getType()
    let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: collectionType)!
    let contractName = FlowEVMBridgeUtils.getContractName(fromType: collectionType)!
    let nftContract = getAccount(contractAddress).contracts.borrow<&{NonFungibleToken}>(name: contractName)!

    let data = nftContract.resolveContractView(
            resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()
        ) as! MetadataViews.NFTCollectionData?
    let display = nftContract.resolveContractView(
            resourceType: nil, viewType: Type<MetadataViews.NFTCollectionDisplay>()
        ) as! MetadataViews.NFTCollectionDisplay?
    let bridged = nftContract.resolveContractView(
            resourceType: nil, viewType: Type<MetadataViews.EVMBridgedMetadata>()
        ) as! MetadataViews.EVMBridgedMetadata?

    if data == nil || display == nil {
        return nil
    }

    return CollectionInfo(
        name: display!.name,
        symbol: bridged?.symbol,
        description: display!.description,
        squareImage: display!.squareImage.file.uri(),
        banner: display!.bannerImage.file.uri(),
        contractURI: bridged?.uri?.uri(),
        collectionStoragePath: data!.storagePath,
        receiverPublicPath: data!.publicPath,
        collectionLength: collection.getLength()
    )
}

/// Returns a dictionary of all the NFT collections owned by the given address.
///
/// @param ownerAddress: The address of the account to get the collections for.
///
/// @return A dictionary of all the NFT collections owned by the given address.
///
access(all)
fun main(ownerAddress: Address): {Type: CollectionInfo} {
    let account = getAuthAccount<auth(BorrowValue) &Account>(ownerAddress)
    let response: {Type: CollectionInfo} = {}

    account.storage.forEachStored(fun (path: StoragePath, type: Type): Bool {
        if !type.isSubtype(of: Type<@{NonFungibleToken.Collection}>()) {
            return true
        }
        
        if response[type] == nil {
            let collection = account.storage.borrow<&{NonFungibleToken.Collection}>(from: path)!
            let info = getInfoFromCollection(collection)
            if info != nil {
                response[type] = info!
            }
        }
        return true
    })

    return response
}